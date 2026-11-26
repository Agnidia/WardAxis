//
//  MockConfigurationService.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if DEBUG
import Foundation
import Observation
import WardAxisManagement

@MainActor @Observable
final class MockConfigurationService: ConfigurationServiceProtocol {
    private(set) var configuration: ManagedConfiguration?
    private(set) var isIdentityRejected = false
    
    @ObservationIgnored private(set) var enrollmentChanges: [EnrollmentState] = []
    @ObservationIgnored private(set) var sceneChanges: [Bool] = []
    
    init(configuration: ManagedConfiguration? = nil) {
        self.configuration = configuration
    }
    
    func enrollmentDidChange(to state: EnrollmentState) {
        enrollmentChanges.append(state)
        if state == .unenrolled {
            configuration = nil
        }
    }
    
    func sceneDidChange(isForeground: Bool) {
        sceneChanges.append(isForeground)
    }
    
    /// Replaces the configuration, as a frame from the server would.
    func setConfiguration(_ configuration: ManagedConfiguration?) {
        self.configuration = configuration
    }
}
#endif
