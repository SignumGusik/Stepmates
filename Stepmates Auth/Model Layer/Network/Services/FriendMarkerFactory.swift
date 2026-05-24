//
//  FriendMarkerFactory.swift
//  Stepmates Auth
//
//  Created by Диана on 29/04/2026.
//

import UIKit

enum FriendMarkerFactory {
    static func makeFallbackImage(username: String) -> UIImage {
        makeLabeledFallbackImage(username: username, size: 54, ringColor: .systemPurple)
    }

    static func makeAvatarImage(_ avatar: UIImage, username: String = "") -> UIImage {
        makeLabeledAvatarImage(avatar, username: username, size: 54, ringColor: .systemPurple)
    }

    static func makeCurrentUserLiveImage(
        username: String = "Я",
        ringColor: UIColor = Constants.orange ?? .systemOrange
    ) -> UIImage {
        makeLabeledFallbackImage(username: username, size: 64, ringColor: ringColor)
    }

    static func makeFriendLiveFallbackImage(username: String) -> UIImage {
        makeLabeledFallbackImage(username: username, size: 58, ringColor: Constants.purple ?? .systemBlue)
    }

    static func makeFriendLiveAvatarImage(_ avatar: UIImage, username: String = "") -> UIImage {
        makeLabeledAvatarImage(avatar, username: username, size: 58, ringColor: Constants.purple ?? .systemBlue)
    }
    
    static func makeCardAvatarFallbackImage(username: String) -> UIImage {
        let size: CGFloat = 56
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let ringColor = Constants.purple ?? .systemBlue
        
        return renderer.image { _ in
            drawCircleBackground(
                in: CGRect(x: 0, y: 0, width: size, height: size),
                ringColor: ringColor
            )
            
            let letter = String(username.prefix(1)).uppercased()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: Constants.manropeExtraBold, size: 20)
                    ?? UIFont.systemFont(ofSize: 20, weight: .black),
                .foregroundColor: UIColor.white
            ]
            let textSize = letter.size(withAttributes: attrs)
            
            letter.draw(
                at: CGPoint(
                    x: size / 2 - textSize.width / 2,
                    y: size / 2 - textSize.height / 2
                ),
                withAttributes: attrs
            )
        }
    }
    
    static func makeRouteEventImage(title: String, color: UIColor) -> UIImage {
        let displayTitle = title.count > 15 ? String(title.prefix(14)) + "…" : title
        let font = UIFont(name: Constants.manropeBold, size: 10)
            ?? UIFont.systemFont(ofSize: 10, weight: .bold)
        let textWidth = displayTitle.size(withAttributes: [.font: font]).width
        let width = max(52, min(116, textWidth + 28))
        let height: CGFloat = 28
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        
        return renderer.image { _ in
            let dotRect = CGRect(x: 0, y: 7, width: 14, height: 14)
            color.setFill()
            UIBezierPath(ovalIn: dotRect).fill()
            
            UIColor.white.setStroke()
            let dotStroke = UIBezierPath(ovalIn: dotRect.insetBy(dx: 1, dy: 1))
            dotStroke.lineWidth = 2
            dotStroke.stroke()
            
            let capsuleRect = CGRect(x: 10, y: 1, width: width - 10, height: 26)
            UIColor.white.withAlphaComponent(0.96).setFill()
            UIBezierPath(roundedRect: capsuleRect, cornerRadius: 13).fill()
            
            color.withAlphaComponent(0.16).setFill()
            UIBezierPath(roundedRect: capsuleRect.insetBy(dx: 1, dy: 1), cornerRadius: 12).fill()
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            
            displayTitle.draw(
                in: capsuleRect.insetBy(dx: 12, dy: 6),
                withAttributes: attrs
            )
        }
    }
}

private extension FriendMarkerFactory {

    static func makeLabeledFallbackImage(
        username: String,
        size: CGFloat,
        ringColor: UIColor
    ) -> UIImage {
        let labelHeight: CGFloat = 24
        let labelTop: CGFloat = 4
        let canvasWidth: CGFloat = max(size + 20, min(110, CGFloat(username.count * 9 + 28)))
        let canvasHeight: CGFloat = size + labelTop + labelHeight

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasWidth, height: canvasHeight))

        return renderer.image { _ in
            let circleX = (canvasWidth - size) / 2
            let circleRect = CGRect(x: circleX, y: 0, width: size, height: size)

            drawCircleBackground(in: circleRect, ringColor: ringColor)

            let letter = String(username.prefix(1)).uppercased()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: Constants.manropeExtraBold, size: size * 0.34)
                    ?? UIFont.systemFont(ofSize: size * 0.34, weight: .bold),
                .foregroundColor: UIColor.white
            ]

            let textSize = letter.size(withAttributes: attrs)
            let textOrigin = CGPoint(
                x: circleRect.midX - textSize.width / 2,
                y: circleRect.midY - textSize.height / 2
            )

            letter.draw(at: textOrigin, withAttributes: attrs)

            drawUsernameLabel(
                username: username,
                canvasWidth: canvasWidth,
                y: size + labelTop,
                height: labelHeight
            )
        }
    }

    static func makeLabeledAvatarImage(
        _ avatar: UIImage,
        username: String,
        size: CGFloat,
        ringColor: UIColor
    ) -> UIImage {
        let labelHeight: CGFloat = 24
        let labelTop: CGFloat = 4
        let displayName = username.isEmpty ? "друг" : username
        let canvasWidth: CGFloat = max(size + 20, min(110, CGFloat(displayName.count * 9 + 28)))
        let canvasHeight: CGFloat = size + labelTop + labelHeight

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasWidth, height: canvasHeight))

        return renderer.image { _ in
            let circleX = (canvasWidth - size) / 2
            let circleRect = CGRect(x: circleX, y: 0, width: size, height: size)

            ringColor.setFill()
            UIBezierPath(ovalIn: circleRect).fill()

            let whiteRingRect = circleRect.insetBy(dx: 4, dy: 4)
            UIColor.white.setFill()
            UIBezierPath(ovalIn: whiteRingRect).fill()

            let imageRect = whiteRingRect.insetBy(dx: 5, dy: 5)
            let imagePath = UIBezierPath(ovalIn: imageRect)
            imagePath.addClip()
            avatar.draw(in: imageRect)

            drawUsernameLabel(
                username: displayName,
                canvasWidth: canvasWidth,
                y: size + labelTop,
                height: labelHeight
            )
        }
    }

    static func drawCircleBackground(in rect: CGRect, ringColor: UIColor) {
        ringColor.setFill()
        UIBezierPath(ovalIn: rect).fill()

        let whiteRingRect = rect.insetBy(dx: 4, dy: 4)
        UIColor.white.setFill()
        UIBezierPath(ovalIn: whiteRingRect).fill()

        let centerRect = whiteRingRect.insetBy(dx: 5, dy: 5)
        ringColor.setFill()
        UIBezierPath(ovalIn: centerRect).fill()
    }

    static func drawUsernameLabel(
        username: String,
        canvasWidth: CGFloat,
        y: CGFloat,
        height: CGFloat
    ) {
        let maxLabelWidth = canvasWidth
        let labelRect = CGRect(x: 0, y: y, width: maxLabelWidth, height: height)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: Constants.manropeBold, size: 11)
                ?? UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]

        let text = username.count > 10
            ? String(username.prefix(9)) + "…"
            : username

        let textSize = text.size(withAttributes: attrs)
        let capsuleWidth = min(max(textSize.width + 16, 38), maxLabelWidth)
        let capsuleRect = CGRect(
            x: (canvasWidth - capsuleWidth) / 2,
            y: y,
            width: capsuleWidth,
            height: height
        )

        UIColor.white.withAlphaComponent(0.96).setFill()
        UIBezierPath(roundedRect: capsuleRect, cornerRadius: height / 2).fill()

        UIColor.black.withAlphaComponent(0.08).setStroke()
        let borderPath = UIBezierPath(roundedRect: capsuleRect, cornerRadius: height / 2)
        borderPath.lineWidth = 1
        borderPath.stroke()

        text.draw(
            with: labelRect.insetBy(dx: 4, dy: 4),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attrs,
            context: nil
        )
    }
}
