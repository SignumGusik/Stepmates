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
        layoutIfNeeded()
        let targetWidth = trackView.bounds.width * p
        fillWidthConstraint?.constant = targetWidth

        if animated {
            UIView.animate(withDuration: 0.25) { self.layoutIfNeeded() }
        } else {
            layoutIfNeeded()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let current = (trackView.bounds.width > 0) ? (fillView.frame.width / trackView.bounds.width) : 0
        fillWidthConstraint?.constant = trackView.bounds.width * current
    }
}
