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
/// Button(L.Onboarding.Welcome.getStarted) { }
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

    // MARK: - Permissions

    enum Permissions {
        enum Camera {
            static var title: LocalizedStringKey {
                "permissions.camera.title"
            }

            static var description: LocalizedStringKey {
                "permissions.camera.description"
            }
        }

        enum Microphone {
            static var title: LocalizedStringKey {
                "permissions.microphone.title"
            }

            static var description: LocalizedStringKey {
                "permissions.microphone.description"
            }
        }

        static var title: LocalizedStringKey {
            "permissions.title"
        }

        static var required: LocalizedStringKey {
            "permissions.required"
        }

        static var openSettings: LocalizedStringKey {
            "permissions.openSettings"
        }

        static func allowButton(permission: String) -> String {
            String(localized: "Allow \(permission)", comment: "Allow permission button")
        }

        static func accessRequired(permission: String) -> String {
            String(localized: "\(permission) Access Required", comment: "Permission access required title")
        }

        static func enableInSettings(permission: String) -> String {
            String(localized: "Please enable \(permission) access in Settings to use this feature.", comment: "Permission denied message")
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

            static var quickActions: LocalizedStringKey {
                "main.home.quickActions"
            }

            static var permissionsDemo: LocalizedStringKey {
                "main.home.permissionsDemo"
            }

            static var commonActions: LocalizedStringKey {
                "main.home.commonActions"
            }

            static var helpCenter: LocalizedStringKey {
                "main.home.helpCenter"
            }

            static var actionsDemo: LocalizedStringKey {
                "main.home.actionsDemo"
            }

            static var splashDemo: LocalizedStringKey {
                "main.home.splashDemo"
            }

            static var requestPermissions: LocalizedStringKey {
                "main.home.requestPermissions"
            }

            static var viewSplashScreen: LocalizedStringKey {
                "main.home.viewSplashScreen"
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

        static var close: LocalizedStringKey {
            "common.close"
        }

        static var done: LocalizedStringKey {
            "common.done"
        }

        static var back: LocalizedStringKey {
            "common.back"
        }

        static var continueButton: LocalizedStringKey {
            "common.continue"
        }

        static var skip: LocalizedStringKey {
            "common.skip"
        }

        static var apply: LocalizedStringKey {
            "common.apply"
        }

        static var tryAgain: LocalizedStringKey {
            "common.tryAgain"
        }

        static var selected: LocalizedStringKey {
            "common.selected"
        }

        static var commonActions: LocalizedStringKey {
            "common.commonActions"
        }

        static var lastTapped: LocalizedStringKey {
            "common.lastTapped"
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

            static var clearCancel: LocalizedStringKey {
                "settings.logs.clearCancel"
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

            static var actionShare: LocalizedStringKey {
                "settings.logs.actionShare"
            }

            static var actionClean: LocalizedStringKey {
                "settings.logs.actionClean"
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
