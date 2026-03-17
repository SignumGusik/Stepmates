//
//  UIButtonExtensions.swift
//  Stepmates Auth
//
//  Created by Диана on 24/01/2026.
//

import UIKit

extension UIButton {
    static func makeButton(title: String, target: Any?, action: Selector) -> UIButton {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(.blue, for: .normal)
        button.setTitle(title, for: .normal)
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
    
    static func makeCircleButton(systemName: String, target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        let image = UIImage(systemName: systemName)
        button.setImage(image, for: .normal)
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 18
        button.clipsToBounds = true

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 36),
            button.heightAnchor.constraint(equalToConstant: 36)
        ])
        button.addTarget(target, action: action, for: .touchUpInside)
        
        return button
    }
    
    static func makeBackButton(target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImage(systemName: "chevron.left")
        button.setImage(image, for: .normal)
        button.tintColor = .black
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
    
    static func makePrimaryBigButton(title: String, target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "Manrope-Medium", size: 18) ?? .systemFont(ofSize: 18, weight: .medium)
        
        button.backgroundColor = Constants.purple ?? .systemBlue
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
    
    static func makeLinkButton(title: String, target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let font = UIFont(name: "Manrope-Bold", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        
        let actionText = NSAttributedString(
            string: title,
            attributes: [
                .font: font,
                .foregroundColor: (Constants.purple ?? .systemBlue)
            ]
        )
        
        let full = NSMutableAttributedString()
        full.append(actionText)
        
        button.setAttributedTitle(full, for: .normal)
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
    
    static func makeRoundIconButton(imageName: String, target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        button.setImage(UIImage(named: imageName), for: .normal)
        button.tintColor = Constants.blue

        button.backgroundColor = Constants.lightPurple
        button.layer.cornerRadius = 25
        button.clipsToBounds = true

        button.imageView?.contentMode = .scaleAspectFit
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
    
    static func makeHomeInfoButton(
            title: String,
            subtitle: String,
            imageName: String,
            backgroundColor: UIColor,
            target: Any?,
            action: Selector
        ) -> UIButton {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            
            var config = UIButton.Configuration.plain()
            config.image = UIImage(named: imageName)
            config.imagePlacement = .leading
            config.imagePadding = 10
            config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
            
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: Constants.manropeMedium, size: 18) ?? UIFont.systemFont(ofSize: 18, weight: .medium),
                .foregroundColor: UIColor.white
            ]
            
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: Constants.manropeMedium, size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.white
            ]
            
            config.attributedTitle = AttributedString(NSAttributedString(string: title, attributes: titleAttributes))
            config.attributedSubtitle = AttributedString(NSAttributedString(string: subtitle, attributes: subtitleAttributes))
            
            button.configuration = config
            button.configurationUpdateHandler = { btn in
                btn.configuration?.baseForegroundColor = .white
            }
            
            button.backgroundColor = backgroundColor
            button.layer.cornerRadius = 20
            button.clipsToBounds = true
            button.contentHorizontalAlignment = .leading
            
            button.addTarget(target, action: action, for: .touchUpInside)
            return button
        }
    
    static func makeImageButton(
        imageName: String,
        target: Any?,
        action: Selector
    ) -> UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let image = UIImage(named: imageName)?.withRenderingMode(.alwaysOriginal)
        button.setImage(image, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        
        button.backgroundColor = .clear
        button.clipsToBounds = false
        
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }

}

extension UIButton {
    static func makeSearchClearButton(target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .systemGray2
        button.alpha = 0
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
    
    static func makeSearchCancelButton(target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Отмена", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: Constants.manropeMedium, size: 12)
            ?? .systemFont(ofSize: 12, weight: .medium)
        button.backgroundColor = Constants.purple ?? .systemBlue
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.alpha = 0
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
    
    static func makeSearchResultActionButton(target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: Constants.manropeMedium, size: 10)
            ?? .systemFont(ofSize: 10, weight: .medium)
        button.layer.cornerRadius = 4
        button.clipsToBounds = true
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
        
    static func makeSearchUsernameButton(target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(.black, for: .normal)
        button.contentHorizontalAlignment = .left
        button.titleLabel?.font = UIFont(name: Constants.manropeMedium, size: 14)
            ?? .systemFont(ofSize: 14, weight: .medium)
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
}

extension UIButton {
    static func makeSettingsActionButton(
        title: String,
        titleColor: UIColor,
        target: Any?,
        action: Selector
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.setTitleColor(titleColor, for: .normal)
        button.titleLabel?.font = UIFont(name: Constants.manropeMedium, size: 16)
            ?? .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .white
        button.layer.cornerRadius = 16
        button.clipsToBounds = true
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
}
