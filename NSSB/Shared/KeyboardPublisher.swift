//
//  KeyboardExtension.swift
//  NSSB
//
//  Created by Anders Munck on 17/06/2022.
//

import Combine
import UIKit


/// Publisher to read keyboard changes.
protocol KeyboardReadable {
    var keyboardPublisher: AnyPublisher<Bool, Never> { get }
}

extension KeyboardReadable {
    var keyboardPublisher: AnyPublisher<Bool, Never> {
        Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .map { _ in true },
            
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in false }
        )
        .eraseToAnyPublisher()
    }
}

/*
 struct ContentView: View, KeyboardReadable {
     
     @State private var text: String = ""
     @State private var isKeyboardVisible = false
     
     var body: some View {
         TextField("Text", text: $text)
             .onReceive(keyboardPublisher) { newIsKeyboardVisible in
                 print("Is keyboard visible? ", newIsKeyboardVisible)
                 isKeyboardVisible = newIsKeyboardVisible
             }
     }
 }
 */
