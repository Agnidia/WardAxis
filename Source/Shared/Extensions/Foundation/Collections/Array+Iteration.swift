//
//  Array+Iteration.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

public extension Array where Element: Equatable {    
    /// Selects the next element in the array or returns the first element if the input element is not found.
    ///
    /// - Parameter element: The element to start from.
    /// - Returns: The next element or the first element if the input element is not found.
    func selectNextOrFirst(from element: Element) -> Element? {
        guard let first else {
            return nil
        }
        
        guard let index = firstIndex(of: element) else {
            return first
        }
        
        var nextIndex = index + 1
        nextIndex = nextIndex >= count ? .zero : nextIndex
        
        return self[nextIndex]
    }
    
    /// Selects the previous element in the array or returns the last element if the input element is not found.
    ///
    /// - Parameter element: The element to start from.
    /// - Returns: The previous element or the last element if the input element is not found.
    func selectPreviousOrLast(from element: Element) -> Element? {
        guard let last else {
            return nil
        }
        
        guard let index = firstIndex(of: element) else {
            return last
        }
        
        var nextIndex = index - 1
        nextIndex = nextIndex < .zero ? count - 1 : nextIndex
        
        return self[nextIndex]
    }
}
