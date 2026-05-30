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
        
        field.backgroundColor = Constants.beige
        field.layer.cornerRadius = 22
        field.clipsToBounds = true

        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftView = padding
        field.leftViewMode = .always
        let placeholderText = placeholder ?? ""
        let placeholderColor = UIColor.black.withAlphaComponent(0.5)
        let placeholderFont = UIFont(name: "Manrope-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)

        field.attributedPlaceholder = NSAttributedString(
            string: placeholderText,
            attributes: [
                .foregroundColor: placeholderColor,
                .font: placeholderFont
            ]
        )
        field.textColor = .black
        field.font = placeholderFont
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

extension UITextField {
    static func makeSearchTextField(target: Any?, action: Selector) -> UITextField {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Поиск"
        textField.textColor = .black
        textField.font = UIFont(name: Constants.manropeMedium, size: 14)
            ?? .systemFont(ofSize: 14, weight: .medium)
        textField.borderStyle = .none
        textField.clearButtonMode = .never
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.returnKeyType = .search
        textField.addTarget(target, action: action, for: .editingChanged)
        return textField
    }
    
}

extension UITextField {
    func attachPasswordVisibilityToggle(
        target: Any?,
        action: Selector,
        tag: Int = 0
    ) {
        let button = UIButton(type: .system)
        button.tag = tag
        button.tintColor = .black
        button.setImage(UIImage(named: "eye_closed"), for: .normal)
        button.setTitle(nil, for: .normal)
        button.backgroundColor = .clear
        button.imageView?.contentMode = .scaleAspectFit
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        button.addTarget(target, action: action, for: .touchUpInside)

        let container = UIView(frame: CGRect(x: 0, y: 0, width: 60, height: 44))
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        button.center = CGPoint(x: 22, y: 22)
        container.addSubview(button)

        rightView = container
        rightViewMode = .always
    }

    func toggleSecureEntryKeepingCursor(trigger button: UIButton? = nil) {
        let wasFirstResponder = isFirstResponder
        let currentText = text

        isSecureTextEntry.toggle()
        let imageName = isSecureTextEntry ? "eye_closed" : "eye"
        button?.setImage(UIImage(named: imageName), for: .normal)

        text = nil
        text = currentText

        if wasFirstResponder {
            becomeFirstResponder()
        }
    }
}

