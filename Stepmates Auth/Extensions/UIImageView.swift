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

extension UIImage {

    func preparedForAvatar(maxSide: CGFloat) -> UIImage {
        let w = size.width
        let h = size.height
        let maxCurrent = max(w, h)
        guard maxCurrent > maxSide else { return self }
        let scale = maxSide / maxCurrent
        let newSize = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

}
