//
//  View+Size.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

extension View {    
    func frame(size: CGFloat, alignment: Alignment = .center) -> some View {
        frame(size: .init(width: size, height: size), alignment: alignment)
    }
    
    func frame(size: CGSize, alignment: Alignment = .center) -> some View {
        frame(width: size.width, height: size.height, alignment: alignment)
    }
    
    func frameInfinite() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
