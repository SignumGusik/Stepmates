//
//  UITextViewExtensions.swift
//  Stepmates Auth
//
//  Created by Диана on 24/01/2026.
//

import UIKit

extension UITextView {
    static func makeTextField(text: String? = nil) -> UITextView {
        let view = UITextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.textColor = .black
        view.font = .systemFont(ofSize: 14)
        view.textAlignment = .center
        return view
    }
}
