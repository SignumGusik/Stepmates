//
//  MapFriendCardView.swift
//  Stepmates Auth
//
//  Created by Codex on 30/05/2026.
//

import UIKit

final class MapFriendCardView: UIView {
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()
    private let followBadge = UILabel()
    private var representedUserId: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }

    func configure(with friend: FriendLiveLocation) {
        representedUserId = friend.userId

        nameLabel.text = friend.username
        statusLabel.text = friend.mapMovementText
        statusLabel.textColor = friend.mapStatusColor
        detailLabel.text = friend.mapDetailText
        avatarImageView.image = FriendMarkerFactory.makeCardAvatarFallbackImage(username: friend.username)

        guard let avatarUrl = friend.avatarUrl, !avatarUrl.isEmpty else {
            return
        }

        AvatarLoader.shared.load(urlString: avatarUrl) { [weak self] image in
            guard let self,
                  self.representedUserId == friend.userId,
                  let image else {
                return
            }

            DispatchQueue.main.async {
                self.avatarImageView.image = image
            }
        }
    }
}

private extension MapFriendCardView {
    func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        applyFloatingCardStyle(
            backgroundColor: UIColor.white.withAlphaComponent(0.97),
            cornerRadius: 24,
            shadowOpacity: 0.14,
            shadowRadius: 18,
            shadowYOffset: 8
        )
        alpha = 0
        isHidden = true

        setupAvatar()
        setupLabels()
        setupFollowBadge()
        addSubviews()
        activateConstraints()
    }

    func setupAvatar() {
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.cornerRadius = 28
        avatarImageView.clipsToBounds = true
        avatarImageView.backgroundColor = Constants.lightPurple ?? UIColor.systemGray5
    }

    func setupLabels() {
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont(name: Constants.manropeExtraBold, size: 18)
            ?? UIFont.systemFont(ofSize: 18, weight: .black)
        nameLabel.textColor = .black
        nameLabel.lineBreakMode = .byTruncatingTail

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = UIFont(name: Constants.manropeBold, size: 13)
            ?? UIFont.systemFont(ofSize: 13, weight: .bold)
        statusLabel.textColor = Constants.purple ?? .systemBlue

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = UIFont(name: Constants.manropeMedium, size: 12)
            ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        detailLabel.textColor = UIColor.black.withAlphaComponent(0.48)
        detailLabel.numberOfLines = 2
    }

    func setupFollowBadge() {
        followBadge.translatesAutoresizingMaskIntoConstraints = false
        followBadge.font = UIFont(name: Constants.manropeBold, size: 11)
            ?? UIFont.systemFont(ofSize: 11, weight: .bold)
        followBadge.text = "открыть"
        followBadge.textAlignment = .center
        followBadge.textColor = .white
        followBadge.backgroundColor = Constants.orange ?? .systemOrange
        followBadge.layer.cornerRadius = 12
        followBadge.clipsToBounds = true
    }

    func addSubviews() {
        addSubview(avatarImageView)
        addSubview(nameLabel)
        addSubview(statusLabel)
        addSubview(detailLabel)
        addSubview(followBadge)
    }

    func activateConstraints() {
        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            avatarImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 56),
            avatarImageView.heightAnchor.constraint(equalToConstant: 56),

            followBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            followBadge.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            followBadge.widthAnchor.constraint(equalToConstant: 58),
            followBadge.heightAnchor.constraint(equalToConstant: 24),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 13),
            nameLabel.trailingAnchor.constraint(equalTo: followBadge.leadingAnchor, constant: -10),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),

            statusLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            statusLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),

            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            detailLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4)
        ])
    }
}

extension FriendLiveLocation {
    var mapMovementKind: MapMovementKind {
        MapMovementKind.fromLiveValue(movementKind ?? movementState)
    }

    var mapMovementText: String {
        if mapMovementKind != .unknown {
            return mapMovementKind.labelText
        }

        if signalQuality == "poor" {
            return "сигнал потерян"
        }

        return "на карте"
    }

    var mapStatusColor: UIColor {
        switch mapMovementKind {
        case .walking:
            return Constants.purple ?? .systemBlue
        case .stationary:
            return Constants.orange ?? .systemOrange
        case .transport:
            return UIColor.systemIndigo
        case .signalLost:
            return UIColor.systemGray
        case .unknown:
            return Constants.purple ?? .systemBlue
        }
    }

    var mapDetailText: String {
        var items = [mapRelativeTimeText]

        if let horizontalAccuracy {
            items.append("точность \(Self.formatAccuracy(horizontalAccuracy))")
        }

        if let confidenceScore {
            items.append("доверие \(confidenceScore)%")
        }

        return items.joined(separator: " · ")
    }

    var mapUpdatedAtDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: updatedAt) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: updatedAt)
    }

    var mapRelativeTimeText: String {
        guard let date = mapUpdatedAtDate else {
            return "обновлено недавно"
        }

        let seconds = max(0, Date().timeIntervalSince(date))

        if seconds < 60 {
            return "только что"
        }

        if seconds < 3600 {
            return "был здесь \(Int(seconds / 60)) мин назад"
        }

        return "был здесь \(Int(seconds / 3600)) ч назад"
    }

    private static func formatAccuracy(_ accuracy: Double) -> String {
        if accuracy >= 1000 {
            return "\(Int((accuracy / 1000).rounded())) км"
        }

        return "\(Int(accuracy.rounded())) м"
    }
}
