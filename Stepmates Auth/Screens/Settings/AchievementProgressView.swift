//
//  AchievementProgressView.swift
//  Stepmates Auth
//
//  Created by Диана on 10/05/2026.
//

import UIKit

final class AchievementProgressView: UIView {

    private let circleView = UIView()
    private let backgroundLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let imageView = UIImageView()

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePath()
    }

    func configure(with achievement: ProfileAchievementDTO) {
        imageView.image = UIImage(named: achievement.imageName)
        titleLabel.text = achievement.shortTitle
        subtitleLabel.text = achievement.shortSubtitle
        setProgress(CGFloat(achievement.progress), animated: true)
    }
}

private extension AchievementProgressView {

    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        circleView.translatesAutoresizingMaskIntoConstraints = false
        circleView.backgroundColor = .clear

        backgroundLayer.strokeColor = UIColor.systemGray5.cgColor
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.lineWidth = 8
        backgroundLayer.lineCap = .round

        progressLayer.strokeColor = (Constants.orange ?? .orange).cgColor
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineWidth = 8
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0

        circleView.layer.addSublayer(backgroundLayer)
        circleView.layer.addSublayer(progressLayer)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.textColor = .black
        titleLabel.font = UIFont(name: Constants.manropeExtraBold, size: 12)
            ?? .systemFont(ofSize: 12, weight: .bold)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        subtitleLabel.textColor = Constants.purple ?? .systemBlue
        subtitleLabel.font = UIFont(name: Constants.manropeMedium, size: 10)
            ?? .systemFont(ofSize: 10, weight: .medium)

        circleView
            .addTo(self)
            .pinTop(toAnchor: topAnchor)
            .centerXOn(self)
            .setSize(width: 80, height: 80)

        imageView
            .addTo(circleView)
            .centerXOn(circleView)
            .centerYOn(circleView)
            .setSize(width: 64, height: 64)

        titleLabel
            .addTo(self)
            .pinTop(toAnchor: circleView.bottomAnchor, constant: 8)
            .pinLeft(toAnchor: leftAnchor)
            .pinRight(toAnchor: rightAnchor)

        subtitleLabel
            .addTo(self)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 4)
            .pinLeft(toAnchor: leftAnchor)
            .pinRight(toAnchor: rightAnchor)
    }

    func updatePath() {
        let center = CGPoint(x: circleView.bounds.midX, y: circleView.bounds.midY)
        let radius = (min(circleView.bounds.width, circleView.bounds.height) - 8) / 2

        let path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        )

        backgroundLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    func setProgress(_ progress: CGFloat, animated: Bool) {
        let value = max(0, min(1, progress))

        if animated {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = progressLayer.presentation()?.strokeEnd ?? progressLayer.strokeEnd
            animation.toValue = value
            animation.duration = 0.35
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            progressLayer.add(animation, forKey: "progress")
        }

        progressLayer.strokeEnd = value
    }
}
