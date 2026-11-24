//
//  ActualSize.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// A view modifier that provides the actual size of the view to a closure.
struct ActualSize: ViewModifier {    
    typealias ActualSizeClosure = Closure.SizeBlock
    
    /// A closure that receives the actual size of the view.
    var closure: ActualSizeClosure = { _ in }
    
    /// Applies the view modifier to the content.
    /// - Parameter content: The content view to which the modifier is applied.
    /// - Returns: A modified view that provides its actual size.
    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geometryProxy -> Color in
                DispatchQueue.main.async {
                    closure(geometryProxy.size)
                }
                return .clear
            })
    }
}

extension View {    
    /// Adds the `ActualSize` view modifier to the view.
    /// - Parameter closure: A closure that receives the actual size of the view.
    /// - Returns: A modified view that provides its actual size to the closure.
    func actualSize(_ closure: @escaping ActualSize.ActualSizeClosure) -> some View {
        modifier(ActualSize(closure: closure))
    }
}
