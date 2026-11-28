//
//  LocalizedStrings.swift
//
//  Created on 30.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// Type-safe localized string accessors organized by feature.
///
/// This enum provides centralized access to all localized strings in the app.
/// Use `L` as a shorthand namespace for accessing localized strings.
///
/// Example:
/// ```swift
/// Text(L.Splash.title)
/// Button(L.Common.done) { }
/// ```
@MainActor
enum L {
    // MARK: - Splash
    
    enum Splash {
        static var title: LocalizedStringKey {
            "splash.title"
        }
        
        static var subtitle: LocalizedStringKey {
            "splash.subtitle"
        }
    }
    
    // MARK: - Main Tabs
    
    enum Main {
        enum Tab {
            static var home: LocalizedStringKey {
                "main.tab.home"
            }
            
            static var settings: LocalizedStringKey {
                "main.tab.settings"
            }
        }
        
        enum Home {
            static var title: LocalizedStringKey {
                "main.home.title"
            }
            
            static var welcome: LocalizedStringKey {
                "main.home.welcome"
            }
            
            static var welcomeSubtitle: LocalizedStringKey {
                "main.home.welcomeSubtitle"
            }
            
            static var features: LocalizedStringKey {
                "main.home.features"
            }
            
            static var helpCenter: LocalizedStringKey {
                "main.home.helpCenter"
            }
        }
    }
    
    // MARK: - Common
    
    enum Common {
        static var ok: LocalizedStringKey {
            "common.ok"
        }
        
        static var cancel: LocalizedStringKey {
            "common.cancel"
        }
        
        static var done: LocalizedStringKey {
            "common.done"
        }
        
        static var tryAgain: LocalizedStringKey {
            "common.tryAgain"
        }
    }
    
    // MARK: - Settings
    
    enum Settings {
        static var title: LocalizedStringKey {
            "settings.title"
        }
        
        static var placeholder: LocalizedStringKey {
            "settings.placeholder"
        }
        
        static var appearance: LocalizedStringKey {
            "settings.appearance"
        }
        
        static var privacy: LocalizedStringKey {
            "settings.privacy"
        }
        
        static var darkMode: LocalizedStringKey {
            "settings.darkMode"
        }
        
        static var analyticsEnabled: LocalizedStringKey {
            "settings.analyticsEnabled"
        }
        
        static var diagnostics: LocalizedStringKey {
            "settings.diagnostics"
        }
        
        // MARK: - Developer (DEBUG, macOS)
        
        enum Developer {
            static var title: LocalizedStringKey {
                "settings.developer.title"
            }
            
            static var footer: LocalizedStringKey {
                "settings.developer.footer"
            }
            
            static var activate: LocalizedStringKey {
                "settings.developer.activate"
            }
            
            static var deactivate: LocalizedStringKey {
                "settings.developer.deactivate"
            }
            
            static var statusIdle: LocalizedStringKey {
                "settings.developer.status.idle"
            }
            
            static var statusInProgress: LocalizedStringKey {
                "settings.developer.status.inProgress"
            }
            
            static var statusNeedsApproval: LocalizedStringKey {
                "settings.developer.status.needsApproval"
            }
            
            static var statusActivated: LocalizedStringKey {
                "settings.developer.status.activated"
            }
            
            static var statusDeactivated: LocalizedStringKey {
                "settings.developer.status.deactivated"
            }
            
            static var statusPendingReboot: LocalizedStringKey {
                "settings.developer.status.pendingReboot"
            }
            
            static func statusFailed(_ reason: String) -> LocalizedStringKey {
                "settings.developer.status.failed \(reason)"
            }
            
            static var stateTitle: LocalizedStringKey {
                "settings.developer.state.title"
            }
            
            static var stateUnknown: LocalizedStringKey {
                "settings.developer.state.unknown"
            }
            
            static var stateNotInstalled: LocalizedStringKey {
                "settings.developer.state.notInstalled"
            }
            
            static var stateAwaitingApproval: LocalizedStringKey {
                "settings.developer.state.awaitingApproval"
            }
            
            static var stateEnabled: LocalizedStringKey {
                "settings.developer.state.enabled"
            }
            
            static var stateDisabled: LocalizedStringKey {
                "settings.developer.state.disabled"
            }
            
            static var stateUninstalling: LocalizedStringKey {
                "settings.developer.state.uninstalling"
            }
        }
        
        // MARK: - Logs Viewer
        
        enum Logs {
            static var title: LocalizedStringKey {
                "settings.logs.title"
            }
            
            static var empty: LocalizedStringKey {
                "settings.logs.empty"
            }
            
            static var filterEmpty: LocalizedStringKey {
                "settings.logs.filterEmpty"
            }
            
            static var clearTitle: LocalizedStringKey {
                "settings.logs.clearTitle"
            }
            
            static var clearMessage: LocalizedStringKey {
                "settings.logs.clearMessage"
            }
            
            static var clearConfirm: LocalizedStringKey {
                "settings.logs.clearConfirm"
            }
            
            static var errorTitle: LocalizedStringKey {
                "settings.logs.errorTitle"
            }
            
            static var errorFileMissing: LocalizedStringKey {
                "settings.logs.errorFileMissing"
            }
            
            static var errorPermissionDenied: LocalizedStringKey {
                "settings.logs.errorPermissionDenied"
            }
            
            static var errorReadFailed: LocalizedStringKey {
                "settings.logs.errorReadFailed"
            }
            
            static var errorWriteFailed: LocalizedStringKey {
                "settings.logs.errorWriteFailed"
            }
            
            static var errorShareFailed: LocalizedStringKey {
                "settings.logs.errorShareFailed"
            }
            
            static var clearedToast: LocalizedStringKey {
                "settings.logs.clearedToast"
            }
            
            static var rawBadge: LocalizedStringKey {
                "settings.logs.rawBadge"
            }
            
            static var testButton: LocalizedStringKey {
                "settings.logs.testButton"
            }
            
            static var unsupportedPlatform: LocalizedStringKey {
                "settings.logs.unsupportedPlatform"
            }
            
            static var copyAction: LocalizedStringKey {
                "settings.logs.copyAction"
            }
            
            static var levelError: LocalizedStringKey {
                "settings.logs.level.error"
            }
            
            static var levelWarning: LocalizedStringKey {
                "settings.logs.level.warning"
            }
            
            static var levelInfo: LocalizedStringKey {
                "settings.logs.level.info"
            }
            
            static var levelDebug: LocalizedStringKey {
                "settings.logs.level.debug"
            }
            
            /// Counter row text — `(total entries, hidden by filter)`.
            ///
            /// Returns a `LocalizedStringKey` with embedded `Int` interpolations so
            /// the SwiftUI `Text(_:)` initializer formats the values via the active
            /// String Catalog entry (`settings.logs.entryCount` with `%lld %lld`).
            static func entryCount(_ total: Int, _ hidden: Int) -> LocalizedStringKey {
                "settings.logs.entryCount \(total) \(hidden)"
            }
            
            enum DateRange {
                static var tenMinutes: LocalizedStringKey {
                    "settings.logs.dateRange.tenMinutes"
                }
                
                static var thirtyMinutes: LocalizedStringKey {
                    "settings.logs.dateRange.thirtyMinutes"
                }
                
                static var oneHour: LocalizedStringKey {
                    "settings.logs.dateRange.oneHour"
                }
                
                static var oneDay: LocalizedStringKey {
                    "settings.logs.dateRange.oneDay"
                }
                
                static var all: LocalizedStringKey {
                    "settings.logs.dateRange.all"
                }
            }
        }
    }
    
    // MARK: - Help
    
    enum Help {
        static var title: LocalizedStringKey {
            "help.title"
        }
        
        static var placeholder: LocalizedStringKey {
            "help.placeholder"
        }
        
        static var faq: LocalizedStringKey {
            "help.faq"
        }
        
        static var contact: LocalizedStringKey {
            "help.contact"
        }
        
        static var emailSupport: LocalizedStringKey {
            "help.emailSupport"
        }
        
        static var visitHelpCenter: LocalizedStringKey {
            "help.visitHelpCenter"
        }
    }
}
