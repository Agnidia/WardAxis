//
//  SystemExtensionDebugViewModelTests.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
@testable import WardAxis

@Suite("SystemExtensionDebugViewModel")
@MainActor
struct SystemExtensionDebugViewModelTests {
    @Test
    func `Initial state is idle and not busy`() {
        let viewModel = SystemExtensionDebugViewModel(service: MockSystemExtensionService())
        
        #expect(viewModel.status == .idle)
        #expect(!viewModel.isBusy)
    }
    
    @Test
    func `Approval then completion ends activated`() async {
        let service = MockSystemExtensionService(activation: .approvedAndCompleted)
        let viewModel = SystemExtensionDebugViewModel(service: service)
        
        await viewModel.activate()
        
        #expect(viewModel.status == .activated)
        #expect(service.activateCount == 1)
    }
    
    @Test
    func `Deactivation ends deactivated`() async {
        let service = MockSystemExtensionService()
        let viewModel = SystemExtensionDebugViewModel(service: service)
        
        await viewModel.deactivate()
        
        #expect(viewModel.status == .deactivated)
        #expect(service.deactivateCount == 1)
    }
    
    @Test
    func `A reboot-pending result is reported`() async {
        let viewModel = SystemExtensionDebugViewModel(
            service: MockSystemExtensionService(activation: .init(events: [.willCompleteAfterReboot]))
        )
        
        await viewModel.activate()
        
        #expect(viewModel.status == .pendingReboot)
    }
    
    @Test(arguments: [
        SystemExtensionError.unsupportedParentBundleLocation,
        .codeSignatureInvalid,
        .requestCanceled,
        .invalidIdentifier,
        .unknown(code: 42),
    ])
    func `A failed request reports its error`(error: SystemExtensionError) async {
        let viewModel = SystemExtensionDebugViewModel(
            service: MockSystemExtensionService(activation: .init(events: [.needsUserApproval], error: error))
        )
        
        await viewModel.activate()
        
        #expect(viewModel.status == .failed(error))
        #expect(!viewModel.isBusy)
    }
    
    @Test
    func `A stream that ends with no result is a failure, not success`() async {
        let viewModel = SystemExtensionDebugViewModel(
            service: MockSystemExtensionService(activation: .init(events: [.needsUserApproval]))
        )
        
        await viewModel.activate()
        
        #expect(viewModel.status == .failed(.endedWithoutResult))
    }
    
    @Test(.timeLimit(.minutes(1)))
    func `No second request is submitted before the OS answers the first`() async {
        let service = MockSystemExtensionService(activation: .init(events: [], finishes: false))
        let viewModel = SystemExtensionDebugViewModel(service: service)
        
        let first = Task { await viewModel.activate() }
        while service.activateCount == 0 {
            await Task.yield()
        }
        #expect(viewModel.isBusy)
        await viewModel.activate()
        await viewModel.deactivate()
        
        #expect(service.activateCount == 1)
        #expect(service.deactivateCount == 0)
        
        service.finishPending()
        await first.value
        #expect(viewModel.status == .failed(.endedWithoutResult))
    }
    
    @Test(.timeLimit(.minutes(1)), arguments: [nil, SystemExtensionError.requestSuperseded])
    func `A request awaiting approval can be replaced, and its late outcome is ignored`(
        lateOutcome: SystemExtensionError?
    ) async {
        let service = MockSystemExtensionService(activation: .init(events: [.needsUserApproval], finishes: false))
        let viewModel = SystemExtensionDebugViewModel(service: service)
        
        let first = Task { await viewModel.activate() }
        while viewModel.status != .needsApproval {
            await Task.yield()
        }
        #expect(!viewModel.isBusy)
        
        await viewModel.deactivate()
        #expect(viewModel.status == .deactivated)
        
        service.finishPending(throwing: lateOutcome)
        await first.value
        #expect(viewModel.status == .deactivated)
        #expect(service.activateCount == 1)
        #expect(service.deactivateCount == 1)
    }
    
    @Test
    func `A state query reports what the OS returns, and a failure clears it`() async {
        let service = MockSystemExtensionService()
        let viewModel = SystemExtensionDebugViewModel(service: service)
        #expect(viewModel.installState == nil)
        
        service.setInstallState(.success(.enabled))
        await viewModel.refreshInstallState()
        #expect(viewModel.installState == .enabled)
        
        service.setInstallState(.failure(.unsupportedParentBundleLocation))
        await viewModel.refreshInstallState()
        #expect(viewModel.installState == nil)
    }
    
    @Test(.timeLimit(.minutes(1)))
    func `Monitoring polls until its task is cancelled`() async {
        let service = MockSystemExtensionService()
        let viewModel = SystemExtensionDebugViewModel(service: service)
        
        let monitor = Task { await viewModel.monitorInstallState(every: .milliseconds(1)) }
        while service.installStateCount < 3 {
            await Task.yield()
        }
        monitor.cancel()
        await monitor.value
        let countAfterCancel = service.installStateCount
        
        try? await Task.sleep(for: .milliseconds(20))
        #expect(service.installStateCount == countAfterCancel)
    }
    
    @Test(.timeLimit(.minutes(1)), arguments: [
        (true, SystemExtensionInstallState.enabled, SystemExtensionDebugViewModel.Status.activated),
        (false, .notInstalled, .deactivated),
        (false, .uninstalling, .pendingReboot),
    ])
    func `An approval finished outside the request ends the wait`(
        activating: Bool,
        polled: SystemExtensionInstallState,
        expected: SystemExtensionDebugViewModel.Status
    ) async {
        let pendingApproval = MockSystemExtensionService.Script(events: [.needsUserApproval], finishes: false)
        let service = MockSystemExtensionService(activation: pendingApproval, deactivation: pendingApproval)
        let viewModel = SystemExtensionDebugViewModel(service: service)
        
        let request = Task { activating ? await viewModel.activate() : await viewModel.deactivate() }
        while viewModel.status != .needsApproval {
            await Task.yield()
        }
        service.setInstallState(.success(polled))
        await viewModel.refreshInstallState()
        #expect(viewModel.status == expected)
        
        // The request's own late outcome no longer applies.
        service.finishPending(throwing: .requestCanceled)
        await request.value
        #expect(viewModel.status == expected)
    }
    
    @Test(.timeLimit(.minutes(1)))
    func `A state that does not finish the pending request leaves it waiting`() async {
        let service = MockSystemExtensionService(activation: .init(events: [.needsUserApproval], finishes: false))
        let viewModel = SystemExtensionDebugViewModel(service: service)
        
        let request = Task { await viewModel.activate() }
        while viewModel.status != .needsApproval {
            await Task.yield()
        }
        for state in [SystemExtensionInstallState.notInstalled, .awaitingApproval, .disabled, .uninstalling] {
            service.setInstallState(.success(state))
            await viewModel.refreshInstallState()
            #expect(viewModel.status == .needsApproval)
        }
        
        service.finishPending()
        await request.value
    }
}
