//
//  Closure+Default.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

public enum Closure {    
    /// A closure type representing a block of code that takes no parameters and returns no value.
    ///
    /// Useful in scenarios where a simple completion handler is required to indicate
    /// the completion of a task without needing any parameters or return values.
    public typealias EmptyBlock = () -> Void
    
    /// A closure type representing a block of code that takes a single Boolean parameter
    /// and returns no value.
    ///
    /// Useful for closures that require a simple true/false parameter to perform a task.
    public typealias BoolBlock = (Bool) -> Void
    
    /// A closure type representing a block of code that takes a single Integer parameter
    /// and returns no value.
    ///
    /// Useful for closures that work with a 0..Int.max input to perform a task.
    public typealias IntegerBlock = (Int) -> Void
    
    /// A closure type representing a block of code that takes a single Float parameter
    /// and returns no value.
    ///
    /// Useful for closures that work with a 0..Float.max input to perform a task.
    public typealias FloatBlock = (Float) -> Void
    
    /// A closure type representing a block of code that takes a single Double parameter
    /// and returns no value.
    ///
    /// Useful for closures that work with a 0..Double.max input to perform a task.
    public typealias DoubleBlock = (Double) -> Void
    
    /// A closure type representing a block of code that takes a single String parameter
    /// and returns no value.
    ///
    /// Useful for closures that work with a string input to perform a task.
    public typealias StringBlock = (String) -> Void
    
    /// A closure type representing a block of code that takes a single Frame parameter
    /// and returns no value.
    ///
    /// Useful for closures that work with a frame input to perform a task.
    public typealias RectBlock = (CGRect) -> Void
    
    /// A closure type representing a block of code that takes a single Size parameter
    /// and returns no value.
    ///
    /// Useful for closures that work with a size input to perform a task.
    public typealias SizeBlock = (CGSize) -> Void
}
