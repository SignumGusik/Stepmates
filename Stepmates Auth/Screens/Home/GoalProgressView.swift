//
//  GoalProgressView.swift
//  Stepmates Auth
//
//  Created by Диана on 15/03/2026.
//

import UIKit

final class GoalProgressView: UIView {

    private let trackView = UIView()
    private let fillView = UIView()

    private var fillWidthConstraint: NSLayoutConstraint?
    private var currentProgress: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        trackView.translatesAutoresizingMaskIntoConstraints = false
        trackView.backgroundColor = UIColor.white.withAlphaComponent(0.85)
        trackView.layer.cornerRadius = 4
        trackView.clipsToBounds = true

        fillView.translatesAutoresizingMaskIntoConstraints = false
        fillView.backgroundColor = Constants.orange
        fillView.layer.cornerRadius = 4
        fillView.clipsToBounds = true

        addSubview(trackView)
        trackView
            .pinTop(toAnchor: topAnchor, constant: 0)
            .pinLeft(toAnchor: leftAnchor, constant: 0)
            .pinRight(toAnchor: rightAnchor, constant: 0)
            .pinBottom(toAnchor: bottomAnchor, constant: 0)

        trackView.addSubview(fillView)
        fillView
            .pinTop(toAnchor: trackView.topAnchor, constant: 0)
            .pinLeft(toAnchor: trackView.leftAnchor, constant: 0)
            .pinBottom(toAnchor: trackView.bottomAnchor, constant: 0)

        fillWidthConstraint = fillView.widthAnchor.constraint(equalToConstant: 0)
        fillWidthConstraint?.isActive = true
    }

    func setProgress(_ progress: CGFloat, animated: Bool = true) {
        let p = max(0, min(1, progress))
        currentProgress = p
        layoutIfNeeded()
        let targetWidth = trackView.bounds.width * p
        fillWidthConstraint?.constant = targetWidth

        if animated {
            UIView.animate(
                withDuration: 0.28,
                delay: 0,
                usingSpringWithDamping: 0.84,
                initialSpringVelocity: 0.55,
                options: [.curveEaseOut, .beginFromCurrentState]
            ) {
                self.layoutIfNeeded()
            }
        } else {
            layoutIfNeeded()
        }
    }

    func flashSuccess() {
        let baseColor = Constants.orange ?? .systemOrange
        let originalTrackColor = trackView.backgroundColor
        let originalFillColor = fillView.backgroundColor

        trackView.backgroundColor = baseColor.withAlphaComponent(0.24)
        fillView.backgroundColor = baseColor
        fillView.transform = CGAffineTransform(scaleX: 1, y: 1.8)

        UIView.animate(
            withDuration: 0.24,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState]
        ) {
            self.trackView.backgroundColor = originalTrackColor
            self.fillView.backgroundColor = originalFillColor
            self.fillView.transform = .identity
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fillWidthConstraint?.constant = trackView.bounds.width * currentProgress
    }
}
