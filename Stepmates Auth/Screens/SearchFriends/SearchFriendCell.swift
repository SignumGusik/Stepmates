//
//  SearchFriendCell.swift
//  Stepmates Auth
//
//  Created by Диана on 02/02/2026.
//

import UIKit

protocol SearchFriendCellDelegate: AnyObject {
    func onUserTapped(_ user: AccessUsers)
    func onActionTapped(_ user: AccessUsers)
}

final class SearchFriendCell: UITableViewCell {
    enum Mode {
        case friendsSearch
        case groupMemberSearch(isSelected: Bool)
    }
    
    static let reuseId = "SearchFriendCell"

    private var user: AccessUsers?

    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 20
        return imageView
    }()

    private lazy var usernameButton = UIButton.makeSearchUsernameButton(
        target: self,
        action: #selector(onUsernameTapped)
    )

    private lazy var actionButton = UIButton.makeSearchResultActionButton(
        target: self,
        action: #selector(onActionButtonTapped)
    )

    weak var delegate: SearchFriendCellDelegate?

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

private extension SearchFriendCell {
    func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        avatarImageView
            .addTo(contentView)
            .centerYOn(contentView)
            .pinLeft(toAnchor: contentView.leftAnchor, constant: 0)
            .setSize(width: 40, height: 40)

        usernameButton
            .addTo(contentView)
            .centerYOn(contentView)
            .pinLeft(toAnchor: avatarImageView.rightAnchor, constant: 10)

        actionButton
            .addTo(contentView)
            .centerYOn(contentView)
            .pinRight(toAnchor: contentView.rightAnchor, constant: 0)
            .setWidth(113)
            .setHeight(26)
    }

    func randomColor(for username: String) -> UIColor {
        let colors: [UIColor] = [
            Constants.purple ?? .systemBlue,
            Constants.orange ?? .orange,
            Constants.blue ?? .blue,
            UIColor(hex: "#D8DDF8") ?? .systemGray4,
            UIColor(hex: "#000000") ?? .black,
            UIColor(hex: "#D7A692") ?? .brown
        ]
        let index = abs(username.hashValue) % colors.count
        return colors[index]
    }

    func applyActionStyle(for user: AccessUsers) {
        if user.isFriend {
            actionButton.setTitle("Уже друг", for: .normal)
            actionButton.backgroundColor = Constants.grey ?? UIColor.systemGray4
            actionButton.setTitleColor(.black, for: .normal)
            actionButton.isEnabled = true
            return
        }

        if user.requestSent {
            actionButton.setTitle("Запрос", for: .normal)
            actionButton.backgroundColor = Constants.orange ?? .orange
            actionButton.setTitleColor(.white, for: .normal)
            actionButton.isEnabled = true
            return
        }

        if user.requestReceived {
            actionButton.setTitle("Запрос отправлен", for: .normal)
            actionButton.backgroundColor = Constants.orange ?? .orange
            actionButton.setTitleColor(.white, for: .normal)
            actionButton.isEnabled = false
            return
        }

        actionButton.setTitle("Добавить", for: .normal)
        actionButton.backgroundColor = Constants.purple ?? .systemBlue
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.isEnabled = true
    }

    func loadAvatarIfNeeded(for user: AccessUsers) {
        let placeholder = randomColor(for: user.username)
        avatarImageView.image = nil
        avatarImageView.backgroundColor = placeholder

        guard let urlString = user.avatarUrl, !urlString.isEmpty else {
            return
        }

        currentAvatarUrl = urlString
        avatarTask?.cancel()

        avatarTask = AvatarLoader.shared.load(urlString: urlString) { [weak self] (image: UIImage?) in
            guard let self else { return }
            guard self.currentAvatarUrl == urlString else { return }

            if let image {
                self.avatarImageView.image = image
                self.avatarImageView.backgroundColor = .clear
            }
        }
    }
}

extension SearchFriendCell {
    func configure(
        with user: AccessUsers,
        delegate: SearchFriendCellDelegate?,
        mode: Mode = .friendsSearch
    ) {
        self.user = user
        self.delegate = delegate

        usernameButton.setTitle(user.username, for: .normal)

        switch mode {
        case .friendsSearch:
            applyActionStyle(for: user)

        case .groupMemberSearch(let isSelected):
            applyGroupMemberStyle(isSelected: isSelected)
        }

        loadAvatarIfNeeded(for: user)
    }
}

private extension SearchFriendCell {
    @objc func onUsernameTapped() {
        guard let user else { return }
        delegate?.onUserTapped(user)
    }

    @objc func onActionButtonTapped() {
        guard let user else { return }
        delegate?.onActionTapped(user)
    }
}

private extension SearchFriendCell {
    func applyGroupMemberStyle(isSelected: Bool) {
        if isSelected {
            actionButton.setTitle("Добавлен", for: .normal)
            actionButton.backgroundColor = Constants.grey ?? .systemGray4
            actionButton.setTitleColor(.black, for: .normal)
            actionButton.isEnabled = false
        } else {
            actionButton.setTitle("Добавить", for: .normal)
            actionButton.backgroundColor = Constants.purple ?? .systemBlue
            actionButton.setTitleColor(.white, for: .normal)
            actionButton.isEnabled = true
        }
    }
}
