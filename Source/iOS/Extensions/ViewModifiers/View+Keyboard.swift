//
//  View+Keyboard.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if os(iOS)
import Combine
import SwiftUI

/// A class that observes keyboard events and publishes the keyboard height.
@MainActor
private final class KeyboardResponder: ObservableObject {    
    private static var savedCurrentHeight: CGFloat = .zero
    
    /// The current height of the keyboard.
    @Published var currentHeight: CGFloat = KeyboardResponder.savedCurrentHeight {
        didSet {
            KeyboardResponder.savedCurrentHeight = currentHeight
        }
    }
    
    private var cancellable: Set<AnyCancellable> = .init()
    
    /// Initializes a new instance of `KeyboardResponder` and sets up the subscriptions for keyboard events.
    init() {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map(\.keyboardHeight)
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
        
        let didShow = NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)
            .map(\.keyboardHeight)
        let didHide = NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)
            .map { _ in CGFloat(0) }
        
        Publishers.Merge4(willShow, willHide, didShow, didHide)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: update(height:))
            .store(in: &cancellable)
    }
    
    private func update(height: CGFloat) {
        withAnimation {
            currentHeight = height
        }
    }
}

@MainActor
private extension Notification {    
    /// Extracts the keyboard height from the notification's userInfo dictionary.
    var keyboardHeight: CGFloat {
        (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
    }
}

@MainActor
extension View {    
    /// A view modifier that adjusts the view's bottom padding to accommodate the keyboard height.
    ///
    /// - Parameters:
    ///   - minHeight: The minimum height before applying the keyboard avoidance behavior.
    ///   - padding: Additional bottom padding to apply when the keyboard is shown.
    /// - Returns: A view modified to adapt to the keyboard height.
    func adaptToKeyboard(minHeigh: CGFloat = .zero, padding: CGFloat = .padding.m) -> some View {
        modifier(KeyboardAdaptive(minHeigh: minHeigh, padding: padding))
    }
}

/// A view modifier that adjusts the view's bottom padding based on the keyboard height.
private struct KeyboardAdaptive: ViewModifier {    
    @ObservedObject private var keyboard = KeyboardResponder()
    
    let minHeigh: CGFloat
    let padding: CGFloat // additional bottom padding
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboard.currentHeight + (keyboard.currentHeight > minHeigh ? padding : .zero))
            .edgesIgnoringSafeArea(keyboard.currentHeight > minHeigh ? .bottom : [])
            .onDisappear {
                keyboard.currentHeight = .zero
            }
    }
}
#endif
