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
    func `A second request while one is pending is not submitted`() async {
        let service = MockSystemExtensionService(activation: .init(events: [.needsUserApproval], finishes: false))
        let viewModel = SystemExtensionDebugViewModel(service: service)
        
        let first = Task { await viewModel.activate() }
        while viewModel.status != .needsApproval {
            await Task.yield()
        }
        await viewModel.activate()
        await viewModel.deactivate()
        
        #expect(service.activateCount == 1)
        #expect(service.deactivateCount == 0)
        
        service.finishPending()
        await first.value
        #expect(viewModel.status == .failed(.endedWithoutResult))
    }
}
