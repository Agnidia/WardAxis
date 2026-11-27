//
//  AppContainer.swift
//
//  Created on 07.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisManagement
import WardAxisTelemetry

/// Dependency injection container for the application.
///
/// `AppContainer` is the single owner of long-lived services and shared state.
/// Views obtain it via `@Environment(\.appContainer)`. It is `@Observable` so
/// any contained `@Observable` state participates in SwiftUI invalidation.
///
/// Swap real services for mocks through `testing()` / `preview()`; there are no
/// singletons, and the container lives for the duration of the process.
///
/// To add a service: define a `Sendable` protocol (in a `WardAxis*` package when
/// an extension or the agent needs it too), provide a mock in
/// `Source/Shared/Mocks/`, then wire it in `production()`, `preview()`,
/// `testing()` and both branches of `placeholder()`.
@Observable @MainActor
final class AppContainer {
    // MARK: - Services
    
    /// In-app alert presentation manager.
    ///
    /// `AlertPresenterModifier` needs the concrete `AlertManager` for `@Bindable`;
    /// the slot stays `any AlertManagerProtocol` and `RootView` casts once.
    let alertManager: any AlertManagerProtocol
    
    /// Reads, exports, and clears the on-device log file.
    let logReaderService: any LogReaderServiceProtocol
    
    /// Haptic feedback service (no-op on macOS).
    let hapticFeedback: any HapticFeedbackServiceProtocol
    
    /// Opt-in usage telemetry; drops every event until the user consents.
    let telemetry: any TelemetryServiceProtocol
    
    /// The live configuration from the management server, cached for offline launches.
    let configurationService: any ConfigurationServiceProtocol
    
    /// Activates and removes the macOS NetworkFilter system extension.
    let systemExtensionService: any SystemExtensionServiceProtocol
    
    // MARK: - Initialization
    
    private init(
        alertManager: any AlertManagerProtocol,
        logReaderService: any LogReaderServiceProtocol,
        hapticFeedback: any HapticFeedbackServiceProtocol,
        telemetry: any TelemetryServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        systemExtensionService: any SystemExtensionServiceProtocol
    ) {
        self.alertManager = alertManager
        self.logReaderService = logReaderService
        self.hapticFeedback = hapticFeedback
        self.telemetry = telemetry
        self.configurationService = configurationService
        self.systemExtensionService = systemExtensionService
    }
    
    // MARK: - Factories
    
    /// Builds the production container with real service implementations.
    static func production() -> AppContainer {
        // No enrollment flow exists yet, so the device has no client identity
        // and the feed stays idle rather than connecting unauthenticated.
        live(configurationService: ConfigurationService.live(bundle: .main, identityProvider: NoClientIdentityProvider()))
    }
    
    /// The real services; only the configuration feed differs between callers.
    private static func live(configurationService: any ConfigurationServiceProtocol) -> AppContainer {
        AppContainer(
            alertManager: AlertManager(),
            logReaderService: LogReaderService(),
            hapticFeedback: HapticFeedbackService(),
            telemetry: TelemetryService(),
            configurationService: configurationService,
            systemExtensionService: SystemExtensionService(bundle: .main)
        )
    }

#if DEBUG
    /// Builds a container suitable for SwiftUI previews. All services are mocked.
    static func preview(configurationService: MockConfigurationService = MockConfigurationService()) -> AppContainer {
        mocked(logScenario: .sampleEntries, configurationService: configurationService)
    }
    
    /// Builds a container suitable for unit tests. All services are mocked.
    static func testing() -> AppContainer {
        mocked(logScenario: .empty, configurationService: MockConfigurationService())
    }
    
    private static func mocked(logScenario: MockLogReaderService.Scenario, configurationService: MockConfigurationService) -> AppContainer {
        AppContainer(
            alertManager: MockAlertManager(),
            logReaderService: MockLogReaderService(scenario: logScenario),
            hapticFeedback: MockHapticFeedbackService(),
            telemetry: MockTelemetryService(),
            configurationService: configurationService,
            systemExtensionService: MockSystemExtensionService()
        )
    }
#endif

    /// Non-bootstrap default for `@Environment(\.appContainer)`.
    ///
    /// `Application.init` always seeds the environment, so this is reached only
    /// by a misconfigured view tree. `nonisolated` because `@Entry` synthesizes a
    /// nonisolated `defaultValue`; SwiftUI resolves it on the main thread.
    nonisolated static func placeholder() -> AppContainer {
        MainActor.assumeIsolated {
#if DEBUG
            // No assertionFailure: @Entry evaluates the default at process start,
            // including the test host launch, which would crash the test runner.
            testing()
#else
            // Never touches the user's files and never connects: no server URL, no
            // cache, no identity. The system extension service is inert until
            // called, and only a DEBUG view calls it.
            live(configurationService: ConfigurationService(
                apiConfiguration: nil,
                identityProvider: NoClientIdentityProvider(),
                transport: URLSessionWebSocketTransport(),
                cache: NoConfigurationCache()
            ))
#endif
        }
    }
}

// MARK: - Environment

extension AppContainer {
    /// Built once: an `@Entry` default expression runs on every access.
    nonisolated static let environmentDefault: AppContainer = placeholder()
}

extension EnvironmentValues {
    @Entry var appContainer: AppContainer = .environmentDefault
}
