//
//  Shape+Pill.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

extension Shape where Self == RoundedRectangle {
    /// The pill outline of buttons, search fields and tags.
    static var pill: RoundedRectangle {
        RoundedRectangle(cornerRadius: .radius.xxxl)
    }
}
