//
//  AppCoordinatorTests.swift
//
//  Created on 15.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import SwiftUI
import Testing
@testable import WardAxis

@Suite("AppCoordinator tabs and paths")
@MainActor
struct AppCoordinatorTests {
    private static let logs = Route.logs
    
    @Test
    func `push lands on the selected tab's stack by default`() {
        let coordinator = AppCoordinator()
        coordinator.push(.help)
        #expect(coordinator.navigationPath.count == 1)
        
        coordinator.switchTab(to: .settings)
        coordinator.push(.help)
        #expect(coordinator.settingsNavigationPath.count == 1)
        #expect(coordinator.navigationPath.count == 1)
    }
    
    @Test
    func `push in .settings lands on the settings stack whatever tab is selected`() {
        let coordinator = AppCoordinator()
        
        coordinator.push(Self.logs, in: .settings)
        
        #expect(coordinator.settingsNavigationPath.count == 1)
        #expect(coordinator.navigationPath.isEmpty)
    }
    
    @Test
    func `pop and popToRoot act on the named tab`() {
        let coordinator = AppCoordinator()
        coordinator.push(.help, in: .home)
        coordinator.push(Self.logs, in: .settings)
        coordinator.push(.help, in: .settings)
        
        coordinator.pop(in: .settings)
        #expect(coordinator.settingsNavigationPath.count == 1)
        coordinator.popToRoot(in: .settings)
        #expect(coordinator.settingsNavigationPath.isEmpty)
        #expect(coordinator.navigationPath.count == 1)
    }
    
    @Test
    func `AC-6: a dirty tab holds a tab switch until it confirms`() {
        let coordinator = AppCoordinator()
        coordinator.switchTab(to: .settings)
        coordinator.setUnsavedChanges(true, in: .settings)
        
        coordinator.switchTab(to: .home)
        
        #expect(coordinator.selectedTab == .settings)
        #expect(coordinator.blockedTabSwitch == .home)
        
        coordinator.completeBlockedTabSwitch()
        #expect(coordinator.selectedTab == .home)
        #expect(coordinator.blockedTabSwitch == nil)
        #expect(coordinator.tabsWithUnsavedChanges.isEmpty)
    }
    
    @Test
    func `AC-6: Keep editing cancels the held switch`() {
        let coordinator = AppCoordinator()
        coordinator.switchTab(to: .settings)
        coordinator.setUnsavedChanges(true, in: .settings)
        coordinator.switchTab(to: .home)
        
        coordinator.cancelBlockedTabSwitch()
        
        #expect(coordinator.selectedTab == .settings)
        #expect(coordinator.blockedTabSwitch == nil)
    }
    
    @Test
    func `A clean tab switches at once; a deep link to the same tab is no switch`() {
        let coordinator = AppCoordinator()
        coordinator.setUnsavedChanges(true, in: .settings)
        
        coordinator.switchTab(to: .settings)
        #expect(coordinator.selectedTab == .settings)
        
        coordinator.setUnsavedChanges(false, in: .settings)
        coordinator.switchTab(to: .home)
        #expect(coordinator.selectedTab == .home)
    }
    
    @Test
    func `reset clears both paths and the guard`() {
        let coordinator = AppCoordinator()
        coordinator.switchTab(to: .settings)
        coordinator.push(Self.logs, in: .settings)
        coordinator.setUnsavedChanges(true, in: .settings)
        coordinator.switchTab(to: .home)
        
        coordinator.reset()
        
        #expect(coordinator.settingsNavigationPath.isEmpty)
        #expect(coordinator.tabsWithUnsavedChanges.isEmpty)
        #expect(coordinator.blockedTabSwitch == nil)
        #expect(coordinator.selectedTab == .home)
    }
    
    @Test
    func `Route.settings is presented as a sheet`() {
        let coordinator = AppCoordinator()
        
        coordinator.navigate(to: .settings)
        
        #expect(coordinator.presentedSheet == .settings)
    }
    
    @Test
    func `The settings deep link opens the Settings sheet and keeps the selected tab`() throws {
        let coordinator = AppCoordinator()
        
        #expect(try coordinator.handleDeepLink(#require(URL(string: "wardaxis://settings"))))
        #expect(coordinator.presentedSheet == .settings)
        #expect(coordinator.selectedTab == .home)
    }
    
    @Test(arguments: ["wardaxis://profile", "wardaxis://permissions", "wardaxis://", "wardaxis://evil.example"])
    func `A deep link to an unknown host changes nothing`(link: String) throws {
        let coordinator = AppCoordinator()
        
        #expect(try !coordinator.handleDeepLink(#require(URL(string: link))))
        #expect(coordinator.selectedTab == .home)
        #expect(coordinator.presentedSheet == nil)
    }
    
    @Test(arguments: ["https://settings", "other://settings", "wardaxis://user@settings", "wardaxis://settings:42", "wardaxis://settings/path", "wardaxis://settings?token=secret", "wardaxis://settings#fragment"])
    func `A link outside the registered grammar changes no navigation state`(link: String) throws {
        let coordinator = AppCoordinator(deepLinkScheme: "wardaxis")
        #expect(try !coordinator.handleDeepLink(#require(URL(string: link))))
        #expect(coordinator.navigationPath.isEmpty)
        #expect(coordinator.presentedSheet == nil)
    }
    
    @Test
    func `A settings link received during splash survives the phase transition`() throws {
        let coordinator = AppCoordinator(deepLinkScheme: "wardaxis")
        #expect(try coordinator.handleDeepLink(#require(URL(string: "wardaxis://settings"))))
        coordinator.completeSplash()
        #expect(coordinator.presentedSheet == .settings)
    }
    
    @Test
    func `Missing scheme and oversize links fail closed`() throws {
        let coordinator = AppCoordinator(deepLinkScheme: nil)
        #expect(try !coordinator.handleDeepLink(#require(URL(string: "wardaxis://settings"))))
        let configured = AppCoordinator(deepLinkScheme: "wardaxis")
        #expect(try !configured.handleDeepLink(#require(URL(string: "wardaxis://settings/" + String(repeating: "x", count: 2048)))))
    }
    
    @Test
    func `Repeated external help links keep one destination in the navigation stack`() throws {
        let coordinator = AppCoordinator(deepLinkScheme: "wardaxis")
        let link = try #require(URL(string: "wardaxis://help"))
        for _ in 0..<100 {
            #expect(coordinator.handleDeepLink(link))
        }
        #expect(coordinator.navigationPath.count == 1)
    }
}
