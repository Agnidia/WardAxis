//
//  main.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import NetworkExtension

// The process only answers the system; the provider class refuses to start.
autoreleasepool {
    NEProvider.startSystemExtensionMode()
}

dispatchMain()
