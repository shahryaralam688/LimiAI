//
//  KeyboardHelper.swift
//  Limi
//
//  Created by Mac Mini on 17/06/2025.
//


//
//  KeyboardHelper.swift
//  Limi
//
//  Created by Mac Mini on 17/06/2025.
//

import SwiftUI
import Combine

// MARK: - Keyboard Helper
class KeyboardHelper: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var isKeyboardVisible: Bool = false
    
    private var lastKnownKeyboardHeight: CGFloat = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification in
                notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            }
            .map { rect in
                rect.height
            }
            .sink { [weak self] height in
                self?.keyboardHeight = height
                self?.isKeyboardVisible = true
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                self?.keyboardHeight = 0
                self?.isKeyboardVisible = false
            }
            .store(in: &cancellables)
    }
}

// MARK: - View Extension for Keyboard Handling
extension View {
    func keyboardAdaptive() -> some View {
        ModifiedContent(content: self, modifier: KeyboardAdaptive())
    }
}

struct KeyboardAdaptive: ViewModifier {
    @StateObject private var keyboardHelper = KeyboardHelper()
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHelper.keyboardHeight)
            .animation(.easeOut(duration: 0.3), value: keyboardHelper.keyboardHeight)
    }
}
