//
//  Background.swift
//  Stepmates Auth
//
//  Created by Диана on 15/03/2026.
//

import UIKit

final class StarsBackgroundView: UIView {
    private var stars: [(CGPoint, CGFloat, CGFloat)] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = Constants.blue
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if stars.isEmpty {
            generateStars()
            setNeedsDisplay()
        }
    }

    private func generateStars() {
        let count = Int(bounds.width * bounds.height / 7000)
        stars = (0..<count).map { _ in
            let x = CGFloat.random(in: 0...bounds.width)
            let y = CGFloat.random(in: 0...bounds.height)
            let r = CGFloat.random(in: 0.6...1.8)
            let a = CGFloat.random(in: 0.3...1.0)
            return (CGPoint(x: x, y: y), r, a)
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setFillColor(UIColor.white.cgColor)

        for (p, r, a) in stars {
            ctx.setAlpha(a)
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r*2, height: r*2))
        }
    }
}
