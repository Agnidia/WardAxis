//
//  ServerMain.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Logging
import ServerCore

@main
enum ServerMain {
    static func main() async {
        let configuration: AppConfiguration
        do {
            configuration = try AppConfiguration(environment: ProcessInfo.processInfo.environment)
        } catch {
            bootstrapLogging(level: AppConfiguration.defaultLogLevel)
            // ConfigurationError names the variable only, never its value.
            Logger(label: "server").critical("Cannot start: \(error)")
            exit(1)
        }
        
        bootstrapLogging(level: configuration.logLevel)
        let logger = Logger(label: "server")
        var postgresLogger = Logger(label: "server.postgres")
        postgresLogger.logLevel = configuration.logLevel
        postgresLogger = postgresLogger.cappedForPostgres()
        let client = PostgresClientFactory.makeClient(configuration: configuration.database, logger: postgresLogger)
        let dependencies = ServerDependencies.production(
            configuration: configuration,
            client: client,
            logger: logger
        )
        
        do {
            let application = try buildApplication(
                configuration: configuration,
                dependencies: dependencies,
                client: client,
                logger: logger
            )
            // Handles SIGTERM and SIGINT with a graceful shutdown.
            try await application.runService()
        } catch {
            // Driver errors (PSQLError) print a generic description by design; the
            // detailed form needs String(reflecting:), which is never used here.
            logger.critical("Server stopped: \(error)", metadata: .errorType(error))
            exit(1)
        }
    }
    
    private static func bootstrapLogging(level: Logger.Level) {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = level
            return handler
        }
    }
}
