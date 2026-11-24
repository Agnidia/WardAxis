//
//  Log.swift
//
//  Created on 26.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import os
import Synchronization

/// `Log` is a utility structure that provides structured logging functionalities
/// to facilitate easy debugging and error tracking in various components of the application.
///
/// It leverages Apple's unified logging system to categorize and filter logs efficiently.
/// All instances share the process-wide `FileLogHandler.shared` writer (see ADR-FileLogHandler-001
/// in `Source/Shared/Logger/README.md`) so file-descriptor leaks and write-ordering bugs are
/// avoided by construction.
public struct Log: Sendable {
    private static let _configurationLock = Mutex(Configuration.preset(detectEnvironment()))
    
    /// The active logging configuration. Update this value to customise logging behaviour at runtime.
    public static var configuration: Configuration {
        get { _configurationLock.withLock { $0 } }
        set { _configurationLock.withLock { $0 = newValue } }
    }
    
    /// Checks if a specific logging category is currently enabled.
    ///
    /// - Parameter category: The category to check.
    /// - Returns: `true` if the category should produce log output, `false` otherwise.
    public static func isEnabled(_ category: Category) -> Bool {
        configuration.categoryStates[category] ?? false
    }
    
    /// Applies one of the built-in logging presets.
    ///
    /// - Parameter environment: Preset environment to apply.
    public static func configure(for environment: Environment) {
        configuration = Configuration.preset(environment)
    }
    
    /// Applies a custom logging configuration.
    ///
    /// - Parameter configuration: The configuration to apply.
    public static func configure(_ configuration: Configuration) {
        self.configuration = configuration
    }
    
    /// Resets configuration back to the preset for the current runtime environment.
    public static func resetConfiguration() {
        configuration = Configuration.preset(detectEnvironment())
    }
    
    private static func detectEnvironment() -> Environment {
#if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .test
        }
        return .debug
#else
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .test
        }
        return .release
#endif
    }
    
    /// Closure to retrieve the current file log level. Defaults to the active configuration's
    /// `fileLogLevel`. Indirection allows tests / settings to override without mutating
    /// every `Log` instance.
    public static let fileLogLevelProvider: @Sendable () -> Level = { Log.configuration.fileLogLevel }
    
    /// The subsystem for the logs, which utilizes the main bundle identifier
    /// of the application to namespace the logs, enhancing their traceability and filtering.
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.agnidia.wardaxis"
    
    /// The `Logger` instance derived from the OS logging system, configured for a specific logging category.
    private let logger: Logger
    
    /// The specific category for which this `Log` instance is configured.
    private let category: Category
    private let configuration: Configuration
    
    private let urlComponents: URLComponents?
    
    private let fileLogHandler: FileLogHandler?
    
    private static let _dateFormatterCache = Mutex<[Configuration.DateDisplayStyle: DateFormatter]>([:])
    
    /// Initializes a new `Log` instance configured for a specific logging category.
    ///
    /// Creates a logger that outputs to the console (via `os.Logger`) and optionally
    /// to a file via the shared `FileLogHandler`. All `Log` instances share a single
    /// file handler to avoid leaking file descriptors.
    ///
    /// - Parameters:
    ///   - category: The logging category for filtering and organization.
    ///   - configuration: Logging configuration (defaults to current global config).
    ///   - components: Optional URL components for network context metadata.
    ///
    /// - Note: This initializer is non-throwing. File logging uses a shared singleton
    ///         handler; if it failed to initialize, logging gracefully degrades to console-only.
    public init(
        category: Category,
        configuration: Configuration = Log.configuration,
        url components: URLComponents? = nil
    ) {
        logger = Logger(subsystem: Log.subsystem, category: category.rawValue)
        self.category = category
        self.configuration = configuration
        urlComponents = components
        fileLogHandler = configuration.saveToFileByDefault && Self.mayWriteLogFile ? FileLogHandler.shared : nil
    }

    /// A signposter on this log's subsystem and category, for `OSSignposter` intervals
    /// that Instruments correlates with the messages.
    public var signposter: OSSignposter {
        OSSignposter(logger: logger)
    }

    /// Extensions see flows, DNS queries and mail: their logs go to the unified log
    /// only, never to a plain-text file that a backup or sysdiagnose could carry away.
    static let mayWriteLogFile: Bool = isAppBundle(path: Bundle.main.bundlePath)

    static func isAppBundle(path: String) -> Bool {
        !(path.hasSuffix(".appex") || path.hasSuffix(".systemextension") || path.hasSuffix(".xpc"))
    }
    
    public var isEnabled: Bool {
        Self.isEnabled(category)
    }
    
    private static var logUrl: URL {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.agnidia.wardaxis"
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(bundleID, isDirectory: true)
            .appending(path: "log.log")
    }
    
    /// Returns the URL of the log directory where log files are stored.
    /// This can be used to open the log directory in Finder.
    public static var logDirectoryUrl: URL {
        logUrl.deletingLastPathComponent()
    }
}

extension Log: LogProtocol {
    private enum Constants {
        static let prefix = "[WardAxis]"
    }
    
    /// Logs a debug message if logging is enabled for the category of the `Log` instance.
    ///
    /// - Parameters:
    ///   - message: The debug message to be logged.
    ///   - privacy: `.private` when the message holds paths, user data or error descriptions.
    public func debug(_ message: String, privacy: Privacy) {
        performLog(message: message, level: .debug, privacy: privacy)
    }
    
    /// Logs an informational message if logging is enabled for the category of the `Log` instance.
    ///
    /// - Parameters:
    ///   - message: The informational message to be logged.
    ///   - privacy: `.private` when the message holds paths, user data or error descriptions.
    public func info(_ message: String, privacy: Privacy) {
        performLog(message: message, level: .info, privacy: privacy)
    }
    
    /// Logs a warning message if logging is enabled for the category of the `Log` instance.
    ///
    /// Warning messages indicate potential issues or unexpected situations that aren't
    /// necessarily errors but should be investigated. Use this for deprecated APIs,
    /// recoverable errors, or performance concerns.
    ///
    /// - Parameters:
    ///   - message: The warning message to be logged.
    ///   - privacy: `.private` when the message holds paths, user data or error descriptions.
    public func warning(_ message: String, privacy: Privacy) {
        performLog(message: message, level: .warning, privacy: privacy)
    }
    
    /// Logs an error message if logging is enabled for the category of the `Log` instance.
    ///
    /// - Parameters:
    ///   - message: The error message to be logged.
    ///   - privacy: `.private` when the message holds paths, user data or error descriptions.
    public func error(_ message: String, privacy: Privacy) {
        performLog(message: message, level: .error, privacy: privacy)
    }
    
    public static func formatTimestamp(_ date: Date, configuration: Configuration) -> String {
        let style = configuration.dateDisplayStyle
        if style == .none {
            return ""
        }
        return _dateFormatterCache.withLock { cache in
            let formatter: DateFormatter
            if let cachedFormatter = cache[style] {
                formatter = cachedFormatter
            } else {
                let newFormatter = DateFormatter()
                if let format = style.dateFormat {
                    newFormatter.locale = Locale(identifier: "en_US_POSIX")
                    newFormatter.timeZone = .current
                    newFormatter.dateFormat = format
                } else {
                    newFormatter.dateStyle = style.dateStyle
                    newFormatter.timeStyle = style.timeStyle
                }
                cache[style] = newFormatter
                formatter = newFormatter
            }
            return formatter.string(from: date)
        }
    }
    
    private func performLog(message: String, level: Level, privacy: Privacy) {
        guard Self.isEnabled(category) else { return }
        
        let metadata = makeMetadata()
        let consoleHeader = formatConsoleHeader(level: level, metadata: metadata)
        
        sendToConsole(header: consoleHeader, message: message, level: level, privacy: privacy)
        logToFile(message: Self.fileMessage(message, privacy: privacy), metadata: metadata, logLevel: level)
    }
    
    /// The log file is plain text on disk and travels with bug reports, so a private
    /// message reaches it only in debug builds, as with `os.Logger` private values.
    public static func fileMessage(_ message: String, privacy: Privacy) -> String {
#if DEBUG
        message
#else
        privacy == .public ? message : Privacy.redactedPlaceholder
#endif
    }
    
    private func makeMetadata() -> LogMetadata {
        LogMetadata(category: category, info: makeInfo())
    }
    
    private func makeInfo() -> LogMetadata.InfoType? {
        guard let host = urlComponents?.host else { return nil }
        return [host: urlComponents?.port ?? .zero]
    }
    
    private func formatConsoleHeader(level: Level, metadata: LogMetadata) -> String {
        let timestamp = Self.formatTimestamp(metadata.timestamp, configuration: configuration)
        
        let prefix = configuration.consolePrefix(for: level)
        let prefixString = prefix.isEmpty ? "" : "\(prefix) "
        let categoryBadge = category.prefix
        let categoryString = categoryBadge.isEmpty ? "" : "\(categoryBadge) "
        let timestampSegment = timestamp.isEmpty ? "" : " [\(timestamp)]"
        
        return "\(prefixString)\(categoryString)\(Constants.prefix)\(timestampSegment) "
    }
    
    private func sendToConsole(header: String, message: String, level: Level, privacy: Privacy) {
        // os.Logger takes privacy only as a literal argument, hence one call per case.
        switch privacy {
        case .public:
            logger.log(level: level.osLogType, "\(header, privacy: .public)\(message, privacy: .public)")
        case .private:
            logger.log(level: level.osLogType, "\(header, privacy: .public)\(message, privacy: .private)")
        }
    }
    
    /// Writes the log message to file via the shared `FileLogHandler`.
    ///
    /// File writes are non-blocking — `FileLogHandler.log(entry:)` dispatches
    /// on the actor's serial executor. No `Task` or continuation is needed at the call site.
    private func logToFile(message: String, metadata: LogMetadata, logLevel: Level) {
        guard let fileLogHandler else { return }
        
        let fileLogLevel = Self.fileLogLevelProvider()
        guard fileLogLevel.contains(logLevel) else { return }
        
        let entry = Self.formatFileEntry(
            message: message,
            metadata: metadata,
            logLevel: logLevel,
            configuration: configuration
        )
        fileLogHandler.log(entry: entry)
    }
}

// MARK: - File Formatting Helpers

private extension Log {
    static func formatFileEntry(
        message: String,
        metadata: LogMetadata,
        logLevel: Level,
        configuration: Configuration
    ) -> String {
        let timestamp = formatTimestamp(metadata.timestamp, configuration: configuration)
        let timestampSegment = timestamp.isEmpty ? nil : "[\(timestamp)]"
        
        let categorySegment = "[\(metadata.category.rawValue)]"
        let levelSegment = "[\(Level.name(logLevel))]"
        
        let infoSegment = formatInfo(metadata.info)
        let infoSuffix = infoSegment.isEmpty ? "" : " | \(infoSegment)"
        
        let header = [timestampSegment, categorySegment, levelSegment]
            .compactMap(\.self)
            .joined(separator: " ")
        
        return "\(header) \(message)\(infoSuffix)"
    }
    
    static func formatInfo(_ info: LogMetadata.InfoType?) -> String {
        guard let info, !info.isEmpty else { return "" }
        
        return info
            .map { key, value in
                let renderedValue = String(describing: value)
                return "\(key)=\(renderedValue)"
            }
            .sorted()
            .joined(separator: ", ")
    }
}
