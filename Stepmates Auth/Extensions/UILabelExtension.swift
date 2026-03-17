//
//  UILabelExtension.swift
//  Stepmates Auth
//
//  Created by Диана on 12/02/2026.
//

import UIKit

extension UILabel {
    static func notificationTitleLabel(text: String) -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 1
        return label
    }
    
    static func notificationSubtitleLabel(text: String) -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        return label
    }
    
    static func makeTitle(text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.numberOfLines = 1
        label.textColor = Constants.purple
        let font = UIFont(name: "MalgunGothicBold", size: 32)
        label.font = font
        return label
    }
    
    static func makeSubtitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.numberOfLines = 0
        label.textColor = .black
        label.font = .systemFont(ofSize: 14, weight: .regular)
        return label
    }

    static func makeFieldLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.numberOfLines = 1
        label.textColor = .black
        label.font = .systemFont(ofSize: 14, weight: .medium)
        return label
    }
    
    static func makeManrope(text: String, style: String, size: CGFloat, color: UIColor = .black) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textColor = color
        label.font = UIFont(name: style, size: size)
        return label
    }
    
}
