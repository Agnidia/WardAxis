//
//  AppContainerTests.swift
//
//  Created on 07.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisManagement
import WardAxisTelemetry
@testable import WardAxis

@Suite("AppContainer")
@MainActor
struct AppContainerTests {
    @Test("AppContainer.testing() wires every service slot to a mock")
    func wiresAllServiceSlots() {
        let container = AppContainer.testing()

        #expect(container.alertManager is MockAlertManager)
        #expect(container.logReaderService is MockLogReaderService)
        #expect(container.hapticFeedback is MockHapticFeedbackService)
        #expect(container.telemetry is MockTelemetryService)
        #expect(container.configurationService is MockConfigurationService)
    }

    @Test("AppContainer.preview(configurationService:) shows the given configuration")
    func previewUsesGivenConfiguration() {
        let configuration = ManagedConfiguration(version: 3, values: ["theme": .string("dark")])
        let container = AppContainer.preview(configurationService: MockConfigurationService(configuration: configuration))

        #expect(container.configurationService.configuration == configuration)
    }

    @Test("The production container starts with the feed idle and not rejected")
    func productionFeedStartsIdle() {
        let container = AppContainer.production()

        #expect(container.configurationService.configuration == nil)
        #expect(!container.configurationService.isIdentityRejected)
    }
}
