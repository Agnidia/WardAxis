//
//  Number+Transform.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

extension CGFloat {    
    static var half: Self {
        0.5
    }
    
    var half: Self {
        self * .half
    }
    
    var doubled: Self {
        self * .two
    }
    
    var tripled: Self {
        self * .three
    }
}

extension Float {    
    static var half: Self {
        0.5
    }
    
    var half: Self {
        self * .half
    }
    
    var doubled: Self {
        self * .two
    }
    
    var tripled: Self {
        self * .three
    }
}

extension Double {    
    static var half: Self {
        0.5
    }
    
    var half: Self {
        self * .half
    }
    
    var doubled: Self {
        self * .two
    }
    
    var tripled: Self {
        self * .three
    }
}

extension Int {    
    var half: Int {
        self / 2
    }
    
    var doubled: Self {
        self * .two
    }
    
    var tripled: Self {
        self * .three
    }
}
