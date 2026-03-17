//
//  UIStackViewExtension.swift
//  Stepmates Auth
//
//  Created by Диана on 12/02/2026.
//

import UIKit

extension UIStackView {
    static func createTextStack(arrangedSubviews: [UILabel]) -> UIStackView {
        let textStack = UIStackView(arrangedSubviews: arrangedSubviews)
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        return textStack
    }
    
    static func createButtonStack(arrangedSubviews: [UIButton]) -> UIStackView {
        let buttonsStack = UIStackView(arrangedSubviews: arrangedSubviews)
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 12
        buttonsStack.alignment = .center
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        for subview in arrangedSubviews {
            buttonsStack.addArrangedSubview(subview)
        }
        return buttonsStack
    }
    
    static func makeCodeInputStack() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }
    static func makeHomeTopRightButtonsStack(arrangedSubviews:[UIView]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: arrangedSubviews)
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }
    
    static func makeHomeStatsButtonsStack(arrangedSubviews: [UIView]) -> UIStackView {
            let stack = UIStackView(arrangedSubviews: arrangedSubviews)
            stack.axis = .horizontal
            stack.alignment = .fill
            stack.distribution = .fillEqually
            stack.spacing = 10
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }
}
