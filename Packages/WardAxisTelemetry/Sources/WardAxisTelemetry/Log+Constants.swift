//
//  Log+Constants.swift
//
//  Created on 26.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import os

public extension Log {
    struct Level: OptionSet, Sendable, Hashable {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public static let error = Level(rawValue: 1 << 0)
        public static let info = Level(rawValue: 1 << 1)
        public static let debug = Level(rawValue: 1 << 2)
        public static let warning = Level(rawValue: 1 << 3)
        
        public static var base: Level {
            .error
        }
        
        public static var all: Level {
            [.error, .warning, .info, .debug]
        }
        
        /// `.warning` uses `.error`, as `Logger.warning` does; a combined set uses `.default`.
        public var osLogType: OSLogType {
            switch self {
            case .debug: .debug
            case .info: .info
            case .warning, .error: .error
            default: .default
            }
        }
        
        public static func name(_ level: Level) -> String {
            let error: String? = if level.contains(.error) {
                "error"
            } else {
                nil
            }
            
            let info: String? = if level.contains(.info) {
                "info"
            } else {
                nil
            }
            
            let debug: String? = if level.contains(.debug) {
                "debug"
            } else {
                nil
            }
            
            let warning: String? = if level.contains(.warning) {
                "warning"
            } else {
                nil
            }
            
            return [error, info, debug, warning].compactMap(\.self).joined(separator: ", ")
        }
    }
    
    typealias Status = Level
    
    /// Whether a message may be stored as is outside the running process.
    ///
    /// `.private` messages show in Xcode and in Console only with private data enabled,
    /// and reach the log file only in debug builds.
    enum Privacy: Sendable {
        case `public`
        case `private`
        
        public static let redactedPlaceholder = "<private>"
    }
    
    enum Environment: Sendable {
        case debug
        case release
        case test
    }
    
    struct Configuration: Sendable {
        public enum DateDisplayStyle: Sendable, Hashable {
            case full
            case short
            case time
            case none
            
            /// Optional explicit date format string when using custom formatting.
            /// When `nil`, `dateStyle` and `timeStyle` will be used instead.
            public var dateFormat: String? {
                switch self {
                case .time: LogDateFormat.timeWithMilliseconds
                case .full, .short, .none: nil
                }
            }
            
            public var dateStyle: DateFormatter.Style {
                switch self {
                case .full: .full
                case .short: .short
                case .time, .none: .none
                }
            }
            
            public var timeStyle: DateFormatter.Style {
                switch self {
                case .full: .full
                case .short: .short
                case .time: .medium
                case .none: .none
                }
            }
        }
        
        public var categoryStates: [Category: Bool]
        public var label: String
        public var consoleEmojis: [Level: String]
        public var saveToFileByDefault: Bool
        public var fileLogLevel: Level
        public var dateDisplayStyle: DateDisplayStyle
        
        public init(
            categoryStates: [Category: Bool],
            label: String,
            consoleEmojis: [Level: String],
            saveToFileByDefault: Bool,
            fileLogLevel: Level,
            dateDisplayStyle: DateDisplayStyle
        ) {
            self.categoryStates = categoryStates
            self.label = label
            self.consoleEmojis = consoleEmojis
            self.saveToFileByDefault = saveToFileByDefault
            self.fileLogLevel = fileLogLevel
            self.dateDisplayStyle = dateDisplayStyle
        }
        
        public func consolePrefix(for level: Level) -> String {
            let badge = consoleEmojis[level]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return switch (badge.isEmpty, trimmedLabel.isEmpty) {
            case (true, true): ""
            case (true, false): trimmedLabel
            case (false, true): badge
            case (false, false): "\(badge) \(trimmedLabel)"
            }
        }
    }
    
    /// One per component, so Console and `log stream --predicate 'category == "filter"'`
    /// can isolate a single trust boundary.
    enum Category: String, CaseIterable, Sendable {
        case application
        case ui
        case cache
        case storage
        case management
        case policy
        case filter
        case dns
        case tunnel
        case ipc
        case dlp
        case pki
        
        /// Emoji badge used when rendering log messages for this category.
        public var prefix: String {
            switch self {
            case .application: "🗳️"
            case .ui: "🪟"
            case .cache: "💾"
            case .storage: "🗄️"
            case .management: "🔌"
            case .policy: "📜"
            case .filter: "🧱"
            case .dns: "🧭"
            case .tunnel: "🚇"
            case .ipc: "🔀"
            case .dlp: "🔎"
            case .pki: "🔐"
            }
        }
    }
}

extension Log.Configuration {
    fileprivate static var releaseList: [Log.Category: Bool] {
        Dictionary(uniqueKeysWithValues: Log.Category.allCases.map { ($0, false) })
    }
    
    fileprivate static var debugList: [Log.Category: Bool] {
        var states = Dictionary(uniqueKeysWithValues: Log.Category.allCases.map { ($0, true) })
        states[.application] = false
        return states
    }
    
    /// The presets share every console emoji except the one for `debug`.
    private static func consoleEmojis(debug: String) -> [Log.Level: String] {
        [.debug: debug, .info: "ℹ️", .warning: "⚠️", .error: "❌"]
    }
    
    public static func preset(_ environment: Log.Environment) -> Self {
        switch environment {
        case .release:
            .init(
                categoryStates: releaseList,
                label: "",
                consoleEmojis: consoleEmojis(debug: "📝"),
                saveToFileByDefault: true,
                fileLogLevel: .error,
                dateDisplayStyle: .short
            )
        case .debug:
            .init(
                categoryStates: debugList,
                label: "",
                consoleEmojis: consoleEmojis(debug: "🛠"),
                saveToFileByDefault: true,
                fileLogLevel: .debug,
                dateDisplayStyle: .time
            )
        case .test:
            .init(
                categoryStates: Dictionary(uniqueKeysWithValues: Log.Category.allCases.map { ($0, true) }),
                label: "[Tests]",
                consoleEmojis: consoleEmojis(debug: "🛠"),
                saveToFileByDefault: true,
                fileLogLevel: .warning,
                dateDisplayStyle: .none
            )
        }
    }
}

extension Log.Level: Codable {
    public init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(Int.self)
        self.init(rawValue: rawValue)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
