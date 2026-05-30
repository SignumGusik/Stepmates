//
//  MapStatusViews.swift
//  Stepmates Auth
//
//  Created by Codex on 30/05/2026.
//

import UIKit

final class MapSignalBadgeView: UIView {
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }

    func apply(quality: TrackQuality, title: String, detail: String) {
        titleLabel.text = title
        detailLabel.text = detail

        switch quality {
        case .good:
            backgroundColor = UIColor.white.withAlphaComponent(0.94)
            titleLabel.textColor = Constants.purple ?? .systemBlue
            detailLabel.textColor = UIColor.black.withAlphaComponent(0.48)

        case .weak:
            backgroundColor = UIColor.white.withAlphaComponent(0.94)
            titleLabel.textColor = Constants.orange ?? .systemOrange
            detailLabel.textColor = UIColor.black.withAlphaComponent(0.50)

        case .poor:
            backgroundColor = UIColor.black.withAlphaComponent(0.72)
            titleLabel.textColor = .white
            detailLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        }
    }
}

private extension MapSignalBadgeView {
    func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 14
        clipsToBounds = true
        backgroundColor = UIColor.black.withAlphaComponent(0.55)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: Constants.manropeBold, size: 13)
            ?? .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .left

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = UIFont(name: Constants.manropeMedium, size: 11)
            ?? .systemFont(ofSize: 11, weight: .semibold)
        detailLabel.textColor = UIColor.white.withAlphaComponent(0.76)
        detailLabel.textAlignment = .left

        addSubview(titleLabel)
        addSubview(detailLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            detailLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            detailLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
}

final class MapEmptyRoutesView: UIView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }

    func configure(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}

private extension MapEmptyRoutesView {
    func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        applyFloatingCardStyle(
            backgroundColor: UIColor.white.withAlphaComponent(0.94),
            cornerRadius: 22,
            shadowOpacity: 0.10,
            shadowRadius: 14,
            shadowYOffset: 7
        )
        alpha = 0
        isHidden = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: Constants.manropeBold, size: 17)
            ?? UIFont.systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .black
        titleLabel.textAlignment = .center
        titleLabel.text = "Пока нет маршрутов"

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont(name: Constants.manropeMedium, size: 14)
            ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = UIColor.black.withAlphaComponent(0.55)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        subtitleLabel.text = "Когда участники группы начнут гулять, их маршруты появятся здесь"

        addSubview(titleLabel)
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        ])
    }
}
