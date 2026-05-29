//
//  FriendLeaderboardCell.swift
//  Stepmates Auth
//
//  Created by Диана on 16/03/2026.
//

import UIKit

final class FriendLeaderboardCell: UITableViewCell {
    static let reuseId = "FriendLeaderboardCell"

    private let cardView = UIView()
    private let placeContainerView = UIView()
    private let placeLabel = UILabel()

    private let avatarImageView = UIImageView()
    private let usernameLabel = UILabel()
    private let stepsLabel = UILabel()

    private var avatarTask: URLSessionDataTask?
    private var currentAvatarUrl: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarTask?.cancel()
        avatarTask = nil
        currentAvatarUrl = nil
        avatarImageView.image = nil
        avatarImageView.backgroundColor = .clear
    }
}

private extension FriendLeaderboardCell {

    func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.layer.cornerRadius = 20
        cardView.clipsToBounds = true

        placeContainerView.translatesAutoresizingMaskIntoConstraints = false
        placeContainerView.layer.cornerRadius = 15
        placeContainerView.clipsToBounds = true

        placeLabel.translatesAutoresizingMaskIntoConstraints = false
        placeLabel.textAlignment = .center
        placeLabel.textColor = .black

        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 12
        avatarImageView.layer.borderWidth = 1
        avatarImageView.layer.borderColor = UIColor.black.cgColor
        avatarImageView.backgroundColor = .systemGray5

        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.textColor = .black

        stepsLabel.translatesAutoresizingMaskIntoConstraints = false
        stepsLabel.textColor = .black
        stepsLabel.textAlignment = .right

        // card
        cardView
            .addTo(contentView)
            .pinTop(toAnchor: contentView.topAnchor, constant: 4)
            .pinLeft(toAnchor: contentView.leftAnchor, constant: 6)
            .pinRight(toAnchor: contentView.rightAnchor, constant: -6)
            .pinBottom(toAnchor: contentView.bottomAnchor, constant: -4)

        // place container
        placeContainerView
            .addTo(cardView)
            .centerYOn(cardView)
            .pinLeft(toAnchor: cardView.leftAnchor, constant: 0)
            .setWidth(48)
            .setHeight(53)

        placeLabel
            .addTo(placeContainerView)
            .centerXOn(placeContainerView)
            .centerYOn(placeContainerView)

        // avatar
        avatarImageView
            .addTo(cardView)
            .centerYOn(cardView)
            .pinLeft(toAnchor: placeContainerView.rightAnchor, constant: 12)
            .setSize(width: 24, height: 24)

        // username
        usernameLabel
            .addTo(cardView)
            .centerYOn(cardView)
            .pinLeft(toAnchor: avatarImageView.rightAnchor, constant: 8)

        // steps
        stepsLabel
            .addTo(cardView)
            .centerYOn(cardView)
            .pinRight(toAnchor: cardView.rightAnchor, constant: -11)
    }

    func applyColors(place: Int, isMe: Bool) {
        // ✅ как просила: топ-3 синие 70/50/40, остальные серые, я — оранжевый 40
        if isMe {
            cardView.backgroundColor = (Constants.orange ?? .orange).withAlphaComponent(0.40)
            placeContainerView.backgroundColor = (Constants.orange ?? .orange).withAlphaComponent(0.70)
            return
        }

        let blue = Constants.blue ?? .systemBlue
        let gray = UIColor(hex: "#E9E9E9") ?? UIColor(white: 0.92, alpha: 1)
        let grayPlace = UIColor(hex: "#DDDDDD") ?? UIColor(white: 0.86, alpha: 1)

        switch place {
        case 1:
            cardView.backgroundColor = blue.withAlphaComponent(0.70)
            placeContainerView.backgroundColor = blue.withAlphaComponent(0.85)
        case 2:
            cardView.backgroundColor = blue.withAlphaComponent(0.50)
            placeContainerView.backgroundColor = blue.withAlphaComponent(0.70)
        case 3:
            cardView.backgroundColor = blue.withAlphaComponent(0.40)
            placeContainerView.backgroundColor = blue.withAlphaComponent(0.60)
        default:
            cardView.backgroundColor = gray
            placeContainerView.backgroundColor = grayPlace
        }
    }

    func applyFonts(place: Int) {
        // ✅ у победителей жирный
        if place <= 3 {
            placeLabel.font = UIFont(name: Constants.manropeExtraBold, size: 24)
                ?? .systemFont(ofSize: 24, weight: .heavy)
            usernameLabel.font = UIFont(name: Constants.manropeExtraBold, size: 16)
                ?? .systemFont(ofSize: 16, weight: .heavy)
            stepsLabel.font = UIFont(name: Constants.manropeExtraBold, size: 16)
                ?? .systemFont(ofSize: 16, weight: .heavy)
        } else {
            placeLabel.font = UIFont(name: "Manrope-Medium", size: 24)
                ?? .systemFont(ofSize: 24, weight: .medium)
            usernameLabel.font = UIFont(name: "Manrope-Medium", size: 16)
                ?? .systemFont(ofSize: 16, weight: .medium)
            stepsLabel.font = UIFont(name: "Manrope-Medium", size: 16)
                ?? .systemFont(ofSize: 16, weight: .medium)
        }
    }

    func loadAvatar(avatarUrl: String?, placeholderColor: UIColor) {
        avatarTask?.cancel()
        avatarTask = nil

        avatarImageView.image = nil
        avatarImageView.backgroundColor = placeholderColor

        guard let avatarUrl, avatarUrl.isEmpty == false else {
            return
        }

        currentAvatarUrl = avatarUrl
        avatarTask = AvatarLoader.shared.load(urlString: avatarUrl) { [weak self] image in
            guard let self else { return }
            guard self.currentAvatarUrl == avatarUrl else { return }

            if let image {
                self.avatarImageView.image = image
                self.avatarImageView.backgroundColor = .clear
            } else {
                // если не загрузилось — оставим плейсхолдер
                self.avatarImageView.image = nil
                self.avatarImageView.backgroundColor = placeholderColor
            }
        }
    }
}

extension FriendLeaderboardCell {

    func configure(with item: FriendLeaderboardItem) {
        placeLabel.text = "\(item.place)"
        usernameLabel.text = item.username
        stepsLabel.text = Self.formatSteps(item.steps)

        applyFonts(place: item.place)
        applyColors(place: item.place, isMe: item.isCurrentUser)

        // avatar
        if let img = item.avatarImage {
            avatarImageView.image = img
            avatarImageView.backgroundColor = .clear
        } else {
            loadAvatar(avatarUrl: item.avatarUrl, placeholderColor: item.avatarColor)
        }
    }

    private static func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }
}
