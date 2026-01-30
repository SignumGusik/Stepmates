//
//  UITextFieldExtensions.swift
//  Stepmates Auth
//
//  Created by Диана on 24/01/2026.
//

import UIKit

extension UITextField {
    
    static func makeTextField(text: String? = nil, placeholder: String? = nil) -> UITextField {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.layer.cornerRadius = 5
        field.layer.borderWidth = 1
        field.clipsToBounds = true
        field.text = text
        field.placeholder = placeholder
        return field
    }
    
    static func makeEmailField(placeholder: String = "Email", delegate: UITextFieldDelegate? = nil) -> UITextField {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = placeholder
        field.textContentType = .emailAddress
        field.keyboardType = .emailAddress
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.delegate = delegate
        return field
    }
    
    static func makePasswordField(placeholder: String = "Password", delegate: UITextFieldDelegate? = nil) -> UITextField {
        let field = UITextField.makeEmailField(placeholder: placeholder)
        field.textContentType = .password
        field.autocapitalizationType = .none
        field.isSecureTextEntry = true
        field.delegate = delegate
        return field
    }
}
