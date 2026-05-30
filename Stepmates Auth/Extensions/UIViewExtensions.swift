//
//  UIViewExtensions.swift
//  Stepmates Auth
//
//  Created by Диана on 24/01/2026.
//

import UIKit

// MARK - AutoLayout Helpers (centering/sizing)
extension UIView {
    
    @discardableResult
    func addTo(_ view: UIView) -> UIView {
        translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self)
        return self
    }
    
    @discardableResult
    func centerXOn(_ view: UIView) -> UIView {
        translatesAutoresizingMaskIntoConstraints = false
        centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        return self
    }
    
    @discardableResult
    func centerYOn(_ view: UIView) -> UIView {
        translatesAutoresizingMaskIntoConstraints = false
        centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        return self
    }
    
    @discardableResult
    func centerOn(_ view: UIView) -> UIView {
        translatesAutoresizingMaskIntoConstraints = false
        return centerXOn(view).centerYOn(view)
    }
    
    @discardableResult
    func setDefaultFieldSize(superview: UIView) -> UIView {
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 40).isActive = true
        widthAnchor.constraint(equalTo: superview.widthAnchor, multiplier: 0.5).isActive = true
        return self
    }
    
    @discardableResult
        func setSize(width: CGFloat, height: CGFloat) -> Self {
            NSLayoutConstraint.activate([
                widthAnchor.constraint(equalToConstant: width),
                heightAnchor.constraint(equalToConstant: height)
            ])
            return self
    }
}

// MARK - AutoLayout Helpers (pinning edges)
extension UIView {
    
    @discardableResult
    func pinTop(toAnchor: NSLayoutYAxisAnchor, constant: CGFloat = 0) -> UIView {
        translatesAutoresizingMaskIntoConstraints = false
        topAnchor.constraint(equalTo: toAnchor, constant: constant).isActive = true
        return self
    }
    
    @discardableResult
    func pinBottom(toAnchor: NSLayoutYAxisAnchor, constant: CGFloat = 0) -> UIView {
        translatesAutoresizingMaskIntoConstraints = false
        bottomAnchor.constraint(equalTo: toAnchor, constant: constant).isActive = true
        return self
    }
    
    @discardableResult
    func pinRight(toAnchor: NSLayoutXAxisAnchor, constant: CGFloat = 0) -> UIView {
        translatesAutoresizingMaskIntoConstraints = false
        rightAnchor.constraint(equalTo: toAnchor, constant: constant).isActive = true
        return self
    }
    
    @discardableResult
    func pinLeft(toAnchor: NSLayoutXAxisAnchor, constant: CGFloat = 0) -> UIView {
        translatesAutoresizingMaskIntoConstraints = false
        leftAnchor.constraint(equalTo: toAnchor, constant: constant).isActive = true
        return self
    }
    
    @discardableResult
    func pinLeading(to anchor: NSLayoutXAxisAnchor, constant: CGFloat = 0) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        leadingAnchor.constraint(equalTo: anchor, constant: constant).isActive = true
        return self
    }

    @discardableResult
    func pinTrailing(to anchor: NSLayoutXAxisAnchor, constant: CGFloat = 0) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        trailingAnchor.constraint(equalTo: anchor, constant: constant).isActive = true
        return self
    }

    @discardableResult
    func pinHorizontal(to view: UIView, inset: CGFloat = 0) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: inset),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -inset)
        ])
        return self
    }

    @discardableResult
    func pinTrailingLessThanOrEqual(to anchor: NSLayoutXAxisAnchor, constant: CGFloat = 0) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        trailingAnchor.constraint(lessThanOrEqualTo: anchor, constant: constant).isActive = true
        return self
    }
}

extension UIView {
    @discardableResult
    func setHeight(_ h: CGFloat) -> Self {
        heightAnchor.constraint(equalToConstant: h).isActive = true
        return self
    }
    @discardableResult
    func setWidth(_ h: CGFloat) -> Self {
        widthAnchor.constraint(equalToConstant: h).isActive = true
        return self
    }
}

extension UIView {
    @discardableResult
    func pinEdges(to view: UIView, inset: CGFloat = 0) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.topAnchor, constant: inset),
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: inset),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -inset),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -inset)
        ])
        return self
    }

    @discardableResult
    func applyRoundedBackground(
        color: UIColor?,
        cornerRadius: CGFloat,
        clipsToBounds: Bool = true
    ) -> Self {
        backgroundColor = color
        layer.cornerRadius = cornerRadius
        self.clipsToBounds = clipsToBounds
        return self
    }

    @discardableResult
    func applySoftShadow(
        opacity: Float = 0.12,
        radius: CGFloat = 12,
        offset: CGSize = CGSize(width: 0, height: 6),
        color: UIColor = .black
    ) -> Self {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowRadius = radius
        layer.shadowOffset = offset
        return self
    }

    @discardableResult
    func applyFloatingCardStyle(
        backgroundColor: UIColor = UIColor.white.withAlphaComponent(0.96),
        cornerRadius: CGFloat = 22,
        shadowOpacity: Float = 0.12,
        shadowRadius: CGFloat = 14,
        shadowYOffset: CGFloat = 7
    ) -> Self {
        applyRoundedBackground(color: backgroundColor, cornerRadius: cornerRadius, clipsToBounds: false)
        applySoftShadow(
            opacity: shadowOpacity,
            radius: shadowRadius,
            offset: CGSize(width: 0, height: shadowYOffset)
        )
        return self
    }

    @discardableResult
    func applyTopRoundedPanelStyle(
        color: UIColor?,
        cornerRadius: CGFloat = 20
    ) -> Self {
        backgroundColor = color
        layer.cornerRadius = cornerRadius
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        clipsToBounds = true
        return self
    }
}

extension UIView {
    static func makeSearchBarContainer() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = Constants.lightPurple
        view.layer.cornerRadius = 25
        view.clipsToBounds = true
        return view
    }
    static func makeAvatarCircle(size: CGFloat = 28) -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = size / 2
        view.clipsToBounds = true
        return view
    }
    static func makeAvatarImageView(size: CGFloat) -> UIImageView {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = size / 2
        iv.backgroundColor = .systemGray5
        iv.isUserInteractionEnabled = true
        return iv

    }
}
