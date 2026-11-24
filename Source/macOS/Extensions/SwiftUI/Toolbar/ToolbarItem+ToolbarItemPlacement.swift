//
//  ToolbarItem+ToolbarItemPlacement.swift
//
//  Created on 08.03.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

#if os(macOS)

public extension ToolbarItemPlacement {
    @MainActor static let navigationBarTrailing: ToolbarItemPlacement = .automatic
}

#endif
