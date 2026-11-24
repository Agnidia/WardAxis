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
    
    @Test(arguments: ["wardaxis://profile", "wardaxis://permissions", "wardaxis://", "wardaxis://evil.example"])
    func `A deep link to an unknown host changes nothing`(link: String) throws {
        let coordinator = AppCoordinator()
        
        #expect(try !coordinator.handleDeepLink(#require(URL(string: link))))
        #expect(coordinator.selectedTab == .home)
        #expect(coordinator.presentedSheet == nil)
    }
}
