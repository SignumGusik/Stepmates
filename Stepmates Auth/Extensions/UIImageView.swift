//
//  UIImageView.swift
//  Stepmates Auth
//
//  Created by Диана on 17/03/2026.
//

import UIKit

extension UIImageView {
    static func makeSearchIcon() -> UIImageView {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "magnifyingglass")
        imageView.tintColor = .systemGray2
        imageView.contentMode = .scaleAspectFit
        return imageView
    }
}
