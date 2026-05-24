//
//  GroupLeaderboardCell.swift
//  Stepmates Auth
//
//  Created by Диана on 05/05/2026.
//

import UIKit

final class GroupLeaderboardCell: UITableViewCell {

    static let reuseId = "GroupLeaderboardCell"

    private let cardView = UIView()
    private let placeContainerView = UIView()
    private let placeLabel = UILabel()

    private let avatarImageView = UIImageView()
    private let adminImageView = UIImageView()

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
        avatarImageView.backgroundColor = .systemGray5
        adminImageView.isHidden = true

        placeLabel.text = nil
        usernameLabel.text = nil
        stepsLabel.text = nil
    }

    func configure(with item: GroupLeaderboardItem) {
        placeLabel.text = "\(item.place)"
        usernameLabel.text = item.isCurrentUser ? "Я" : item.username
        stepsLabel.text = Self.formatSteps(item.steps)
        adminImageView.isHidden = !item.isAdmin

        applyFonts(place: item.place)
        applyColors(place: item.place, isMe: item.isCurrentUser)

        loadAvatar(
            avatarUrl: item.avatarUrl,
            placeholderColor: item.avatarColor
        )
    }
}

private extension GroupLeaderboardCell {

    func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.layer.cornerRadius = 19
        cardView.clipsToBounds = true

        placeContainerView.translatesAutoresizingMaskIntoConstraints = false
        placeContainerView.layer.cornerRadius = 19
        placeContainerView.clipsToBounds = true

        placeLabel.translatesAutoresizingMaskIntoConstraints = false
        placeLabel.textAlignment = .center
        placeLabel.textColor = .black

        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 14
        avatarImageView.layer.borderWidth = 1
        avatarImageView.layer.borderColor = UIColor.black.cgColor
        avatarImageView.backgroundColor = .systemGray5

        adminImageView.translatesAutoresizingMaskIntoConstraints = false
        adminImageView.image = UIImage(named: "AdminImg")?.withRenderingMode(.alwaysOriginal)
        adminImageView.contentMode = .scaleAspectFit
        adminImageView.isHidden = true

        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.textColor = .black

        stepsLabel.translatesAutoresizingMaskIntoConstraints = false
        stepsLabel.textColor = .black
        stepsLabel.textAlignment = .right

        cardView
            .addTo(contentView)
            .pinTop(toAnchor: contentView.topAnchor, constant: 3)
            .pinLeft(toAnchor: contentView.leftAnchor, constant: 0)
            .pinRight(toAnchor: contentView.rightAnchor, constant: 0)
            .pinBottom(toAnchor: contentView.bottomAnchor, constant: -3)
        
        placeContainerView
            .addTo(cardView)
            .centerYOn(cardView)
            .pinLeft(toAnchor: cardView.leftAnchor, constant: 0)
            .setWidth(54)
            .setHeight(54)

        placeLabel
            .addTo(placeContainerView)
            .centerXOn(placeContainerView)
            .centerYOn(placeContainerView)

        avatarImageView
            .addTo(cardView)
            .centerYOn(cardView)
            .pinLeft(toAnchor: placeContainerView.rightAnchor, constant: 14)
            .setSize(width: 28, height: 28)

        adminImageView
            .addTo(cardView)
            .pinTop(toAnchor: avatarImageView.topAnchor, constant: -10)
            .centerXOn(avatarImageView)
            .setSize(width: 18, height: 18)

        usernameLabel
            .addTo(cardView)
            .centerYOn(cardView)
            .pinLeft(toAnchor: avatarImageView.rightAnchor, constant: 10)

        stepsLabel
            .addTo(cardView)
            .centerYOn(cardView)
            .pinRight(toAnchor: cardView.rightAnchor, constant: -18)
    }

    func applyColors(place: Int, isMe: Bool) {
        let blue = Constants.purple ?? .systemBlue
        let orange = Constants.orange ?? .orange

        if isMe {
            cardView.backgroundColor = orange.withAlphaComponent(0.45)
            placeContainerView.backgroundColor = orange.withAlphaComponent(0.75)
            return
        }

        switch place {
        case 1:
            cardView.backgroundColor = blue.withAlphaComponent(0.70)
            placeContainerView.backgroundColor = blue.withAlphaComponent(0.85)
        case 2:
            cardView.backgroundColor = blue.withAlphaComponent(0.45)
            placeContainerView.backgroundColor = blue.withAlphaComponent(0.60)
        case 3:
            cardView.backgroundColor = orange.withAlphaComponent(0.45)
            placeContainerView.backgroundColor = orange.withAlphaComponent(0.75)
        default:
            cardView.backgroundColor = UIColor(hex: "#E9E9E9") ?? .systemGray5
            placeContainerView.backgroundColor = UIColor(hex: "#DDDDDD") ?? .systemGray4
        }
    }

    func applyFonts(place: Int) {
        let placeFont = UIFont(name: Constants.manropeExtraBold, size: 24)
            ?? .systemFont(ofSize: 24, weight: .bold)

        placeLabel.font = placeFont

        if place <= 3 {
            usernameLabel.font = UIFont(name: Constants.manropeExtraBold, size: 16)
                ?? .systemFont(ofSize: 16, weight: .bold)
            stepsLabel.font = UIFont(name: Constants.manropeExtraBold, size: 16)
                ?? .systemFont(ofSize: 16, weight: .bold)
        } else {
            usernameLabel.font = UIFont(name: Constants.manropeMedium, size: 16)
                ?? .systemFont(ofSize: 16, weight: .medium)
            stepsLabel.font = UIFont(name: Constants.manropeMedium, size: 16)
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
            }
        }
    }

    static func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }
}
