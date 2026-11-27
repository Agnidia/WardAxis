//
//  View+Debug.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisTelemetry

/// A view extension to print debug information during development.
///
/// This extension provides a static method for printing SwiftUI state change
/// diagnostics to the console in debug mode. It utilizes SwiftUI's internal
/// `_printChanges()` function, available only in `DEBUG` builds, to display
/// updates to a view.
///
/// - Note: This method has no effect in release builds.
///
/// Example usage:
/// ```swift
/// struct ContentView: View {
///     var body: some View {
///         Self.printDebugInfo()
///         Text("Hello, Debug!")
///     }
/// }
/// ```
///
/// - Availability:
///   - This method is intended for debugging purposes only.
extension View {
    /// Prints diagnostic information about state changes in a SwiftUI view during development.
    ///
    /// - Note: This function is available only when the `DEBUG` flag is active.
    ///         It has no runtime effect in production builds.
    @ViewBuilder
    static func printDebugInfo() -> some View {
#if DEBUG
        let _ = Self._printChanges()
#endif
    }
}

extension View {
    /// Logs `<name> appeared` in the UI category at debug level, each time the view appears.
    func logAppearance(_ name: String) -> some View {
        onAppear {
            Log(category: .ui).debug("\(name) appeared")
        }
    }
}
