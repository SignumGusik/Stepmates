//
//  NotificationRequestCell.swift.swift
//  Stepmates Auth
//
//  Created by Диана on 12/02/2026.
//

import UIKit

final class NotificationRequestCell: UITableViewCell {

    static let reuseId = "NotificationRequestCell"

    var onAcceptTapped: (() -> Void)?
    var onRejectTapped: (() -> Void)?

    private let avatarContainerView = UIView()
    private let mainAvatarImageView = UIView.makeAvatarImageView(size: 50)
    private let smallAvatarImageView = UIView.makeAvatarImageView(size: 29)
    private var titleMaxWidthConstraint: NSLayoutConstraint?

    private let titleLabel = UILabel()
    private let dateLabel = UILabel()

    private lazy var rejectButton = UIButton.makeNotificationImageButton(
        imageName: "rejectBtn",
        target: self,
        action: #selector(onReject)
    )

    private lazy var acceptButton = UIButton.makeNotificationImageButton(
        imageName: "acceptBtn",
        target: self,
        action: #selector(onAccept)
    )

    private var mainAvatarTask: URLSessionDataTask?
    private var smallAvatarTask: URLSessionDataTask?
    private var currentMainAvatarUrl: String?
    private var currentSmallAvatarUrl: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        onAcceptTapped = nil
        onRejectTapped = nil

        mainAvatarTask?.cancel()
        smallAvatarTask?.cancel()

        mainAvatarTask = nil
        smallAvatarTask = nil
        currentMainAvatarUrl = nil
        currentSmallAvatarUrl = nil

        mainAvatarImageView.image = nil
        smallAvatarImageView.image = nil

        mainAvatarImageView.backgroundColor = .systemGray5
        smallAvatarImageView.backgroundColor = .systemGray5

        smallAvatarImageView.isHidden = true

        titleLabel.attributedText = nil
        dateLabel.text = nil

        acceptButton.alpha = 1
        rejectButton.alpha = 1

        acceptButton.isHidden = false
        rejectButton.isHidden = false
        acceptButton.isEnabled = true
        rejectButton.isEnabled = true
    }
}

// MARK: - Setup
private extension NotificationRequestCell {

    func setupViews() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        avatarContainerView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 2
        titleLabel.textColor = .black
        titleLabel.font = UIFont(name: Constants.manropeMedium, size: 11)
            ?? .systemFont(ofSize: 11, weight: .medium)

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.textColor = .systemGray2
        dateLabel.font = UIFont(name: Constants.manropeMedium, size: 8)
            ?? .systemFont(ofSize: 8, weight: .medium)

        avatarContainerView
            .addTo(contentView)
            .pinLeft(toAnchor: contentView.leftAnchor, constant: 18)
            .centerYOn(contentView)
            .setSize(width: 58, height: 54)

        mainAvatarImageView
            .addTo(avatarContainerView)
            .pinLeft(toAnchor: avatarContainerView.leftAnchor)
            .centerYOn(avatarContainerView)
            .setSize(width: 50, height: 50)

        smallAvatarImageView
            .addTo(avatarContainerView)
            .pinRight(toAnchor: avatarContainerView.rightAnchor)
            .pinBottom(toAnchor: avatarContainerView.bottomAnchor)
            .setSize(width: 29, height: 29)
        
        mainAvatarImageView.layer.borderWidth = 1
        mainAvatarImageView.layer.borderColor = UIColor.black.cgColor

        smallAvatarImageView.layer.borderWidth = 1
        smallAvatarImageView.layer.borderColor = UIColor.black.cgColor

        acceptButton
            .addTo(contentView)
            .centerYOn(contentView)
            .pinRight(toAnchor: contentView.rightAnchor, constant: -18)
            .setSize(width: 30, height: 30)

        rejectButton
            .addTo(contentView)
            .centerYOn(contentView)
            .pinRight(toAnchor: acceptButton.leftAnchor, constant: -8)
            .setSize(width: 30, height: 30)

        titleLabel
            .addTo(contentView)
            .pinTop(toAnchor: mainAvatarImageView.topAnchor, constant: 5)
            .pinLeft(toAnchor: avatarContainerView.rightAnchor, constant: 8)
            .pinRight(toAnchor: rejectButton.leftAnchor, constant: -8)

        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.lineBreakMode = .byWordWrapping
        
        titleMaxWidthConstraint = titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 175)
        titleMaxWidthConstraint?.isActive = true

        dateLabel
            .addTo(contentView)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 2)
            .pinLeft(toAnchor: avatarContainerView.rightAnchor, constant: 8)
            .pinRight(toAnchor: rejectButton.leftAnchor, constant: -8)

        contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true
    }
}

// MARK: - Configure
extension NotificationRequestCell {

    func configure(with item: AppNotificationDTO) {
        dateLabel.text = Self.relativeDateText(from: item.createdAt)

        switch item.type {
        case .friendRequest:
            configureFriendRequest(item)

        case .groupInvite:
            configureGroupInvite(item)

        case .friendRequestAccepted:
            configureFriendAccepted(item)
        }
    }

    private func configureFriendRequest(_ item: AppNotificationDTO) {
        let username = item.fromUser?.username ?? "Пользователь"

        titleLabel.attributedText = makeTitle(
            bold: username,
            regular: " отправил(а) вам запрос в друзья"
        )

        smallAvatarImageView.isHidden = true

        loadMainAvatar(
            item.fromUser?.avatarUrl,
            placeholderColor: randomColor(for: username)
        )

        acceptButton.alpha = 1
        rejectButton.alpha = 1
        acceptButton.isHidden = false
        rejectButton.isHidden = false
    }

    private func configureGroupInvite(_ item: AppNotificationDTO) {
        let username = item.fromUser?.username ?? "Пользователь"
        let groupName = item.group?.name ?? "группу"

        titleLabel.attributedText = makeGroupInviteTitle(
            username: username,
            groupName: groupName
        )

        smallAvatarImageView.isHidden = false

        loadMainAvatar(
            item.group?.avatarUrl,
            placeholderColor: Constants.lightPurple ?? .systemGray5
        )

        loadSmallAvatar(
            item.fromUser?.avatarUrl,
            placeholderColor: randomColor(for: username)
        )

        acceptButton.alpha = 1
        rejectButton.alpha = 1
        acceptButton.isHidden = false
        rejectButton.isHidden = false
    }

    private func configureFriendAccepted(_ item: AppNotificationDTO) {
        let username = item.fromUser?.username ?? "Пользователь"

        titleLabel.attributedText = makeTitle(
            bold: username,
            regular: " принял(а) ваш запрос в друзья"
        )

        smallAvatarImageView.isHidden = true

        loadMainAvatar(
            item.fromUser?.avatarUrl,
            placeholderColor: randomColor(for: username)
        )

        rejectButton.isHidden = true
        acceptButton.isHidden = false
        acceptButton.alpha = 1
        acceptButton.isEnabled = true
    }

    func setLoading(_ isLoading: Bool) {
        rejectButton.isEnabled = !isLoading
        acceptButton.isEnabled = !isLoading

        rejectButton.alpha = isLoading ? 0.5 : 1
        acceptButton.alpha = isLoading ? 0.5 : 1
    }
}

// MARK: - Actions
private extension NotificationRequestCell {

    @objc func onReject() {
        onRejectTapped?()
    }

    @objc func onAccept() {
        onAcceptTapped?()
    }
}

// MARK: - Helpers
private extension NotificationRequestCell {

    func makeTitle(bold: String, regular: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        result.append(NSAttributedString(
            string: bold,
            attributes: [
                .font: UIFont(name: Constants.manropeExtraBold, size: 11)
                    ?? .systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: UIColor.black
            ]
        ))

        result.append(NSAttributedString(
            string: regular,
            attributes: [
                .font: UIFont(name: Constants.manropeMedium, size: 11)
                    ?? .systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: UIColor.black
            ]
        ))

        return result
    }
    
    func makeGroupInviteTitle(username: String, groupName: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let boldFont = UIFont(name: Constants.manropeExtraBold, size: 11)
            ?? .systemFont(ofSize: 11, weight: .bold)

        let regularFont = UIFont(name: Constants.manropeMedium, size: 11)
            ?? .systemFont(ofSize: 11, weight: .medium)

        result.append(NSAttributedString(
            string: username,
            attributes: [
                .font: boldFont,
                .foregroundColor: UIColor.black
            ]
        ))

        result.append(NSAttributedString(
            string: " пригласил(а) вас в группу ",
            attributes: [
                .font: regularFont,
                .foregroundColor: UIColor.black
            ]
        ))

        result.append(NSAttributedString(
            string: "«\(groupName)»",
            attributes: [
                .font: boldFont,
                .foregroundColor: UIColor.black
            ]
        ))

        return result
    }

    func loadMainAvatar(_ avatarUrl: String?, placeholderColor: UIColor) {
        mainAvatarImageView.image = nil
        mainAvatarImageView.backgroundColor = placeholderColor
        currentMainAvatarUrl = avatarUrl

        guard let avatarUrl, avatarUrl.isEmpty == false else { return }

        mainAvatarTask = AvatarLoader.shared.load(urlString: avatarUrl) { [weak self] image in
            guard let self else { return }
            guard self.currentMainAvatarUrl == avatarUrl else { return }

            if let image {
                self.mainAvatarImageView.image = image
                self.mainAvatarImageView.backgroundColor = .clear
            }
        }
    }

    func loadSmallAvatar(_ avatarUrl: String?, placeholderColor: UIColor) {
        smallAvatarImageView.image = nil
        smallAvatarImageView.backgroundColor = placeholderColor
        currentSmallAvatarUrl = avatarUrl

        guard let avatarUrl, avatarUrl.isEmpty == false else { return }

        smallAvatarTask = AvatarLoader.shared.load(urlString: avatarUrl) { [weak self] image in
            guard let self else { return }
            guard self.currentSmallAvatarUrl == avatarUrl else { return }

            if let image {
                self.smallAvatarImageView.image = image
                self.smallAvatarImageView.backgroundColor = .clear
            }
        }
    }

    func randomColor(for username: String) -> UIColor {
        let colors: [UIColor] = [
            Constants.purple ?? .systemBlue,
            Constants.orange ?? .orange,
            Constants.blue ?? .blue,
            UIColor(hex: "#D8DDF8") ?? .systemGray4,
            UIColor(hex: "#D7A692") ?? .brown
        ]

        let index = abs(username.hashValue) % colors.count
        return colors[index]
    }

    static func relativeDateText(from string: String) -> String {
        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date = isoWithFraction.date(from: string)

        if date == nil {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: string)
        }

        guard let date else {
            return ""
        }

        let calendar = Calendar.current

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ru_RU")
        timeFormatter.dateFormat = "HH:mm"

        if calendar.isDateInToday(date) {
            return "Сегодня в \(timeFormatter.string(from: date))"
        }

        if calendar.isDateInYesterday(date) {
            return "Вчера в \(timeFormatter.string(from: date))"
        }

        if let beforeYesterday = calendar.date(byAdding: .day, value: -2, to: Date()),
           calendar.isDate(date, inSameDayAs: beforeYesterday) {
            return "Позавчера в \(timeFormatter.string(from: date))"
        }

        let output = DateFormatter()
        output.locale = Locale(identifier: "ru_RU")
        output.dateFormat = "d MMMM в HH:mm"
        return output.string(from: date)
    }
}
