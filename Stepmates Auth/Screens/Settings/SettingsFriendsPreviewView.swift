//
//  SettingsFriendsPreviewView.swift
//  Stepmates Auth
//
//  Created by Диана on 10/05/2026.
//

import UIKit

final class SettingsFriendsPreviewView: UIView {

    var onAddFriendTapped: (() -> Void)?

    private let avatarsStack = UIStackView()

    private lazy var titleLabel = UILabel.makeManrope(
        text: "0 друзей",
        style: Constants.manropeExtraBold,
        size: 30,
        color: .black
    )

    private lazy var addFriendButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Добавить друга", for: .normal)
        button.setTitleColor(Constants.orange ?? .orange, for: .normal)

        button.titleLabel?.font = UIFont(name: Constants.manropeMedium, size: 13)
            ?? .systemFont(ofSize: 13, weight: .medium)

        button.backgroundColor = (Constants.orange ?? .orange).withAlphaComponent(0.10)
        button.layer.cornerRadius = 18
        button.clipsToBounds = true

        button.addTarget(self, action: #selector(onAddTapped), for: .touchUpInside)
        return button
    }()

    private var avatarTasks: [URLSessionDataTask] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }

    func configure(count: Int, friends: [ProfileFriendPreviewDTO]) {
        avatarTasks.forEach { $0.cancel() }
        avatarTasks.removeAll()

        titleLabel.text = "\(count) \(friendsWord(count))"

        avatarsStack.arrangedSubviews.forEach {
            avatarsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        friends.prefix(6).forEach { friend in
            let avatar = UIView.makeAvatarImageView(size: 30)
            avatar.backgroundColor = randomColor(for: friend.username)
            avatar.layer.borderWidth = 1
            avatar.layer.borderColor = UIColor.black.cgColor
            avatar.setSize(width: 30, height: 30)

            avatarsStack.addArrangedSubview(avatar)

            guard let url = friend.avatarUrl, url.isEmpty == false else { return }

            if let task = AvatarLoader.shared.load(urlString: url) { image in
                if let image {
                    avatar.image = image
                    avatar.backgroundColor = .clear
                }
            } {
                avatarTasks.append(task)
            }
        }
    }
}

private extension SettingsFriendsPreviewView {

    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .white
        layer.cornerRadius = 20
        clipsToBounds = true

        avatarsStack.translatesAutoresizingMaskIntoConstraints = false
        avatarsStack.axis = .horizontal
        avatarsStack.spacing = -8
        avatarsStack.alignment = .center
        avatarsStack.distribution = .fill

        avatarsStack
            .addTo(self)
            .pinTop(toAnchor: topAnchor, constant: 17)
            .pinLeft(toAnchor: leftAnchor, constant: 28)
            .setHeight(30)

        titleLabel
            .addTo(self)
            .pinLeft(toAnchor: leftAnchor, constant: 28)
            .pinBottom(toAnchor: bottomAnchor, constant: -16)

        addFriendButton
            .addTo(self)
            .pinRight(toAnchor: rightAnchor, constant: -18)
            .pinBottom(toAnchor: bottomAnchor, constant: -18)
            .setSize(width: 128, height: 36)
    }

    @objc func onAddTapped() {
        onAddFriendTapped?()
    }

    func friendsWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100

        if mod10 == 1 && mod100 != 11 {
            return "друг"
        }

        if (2...4).contains(mod10) && !(12...14).contains(mod100) {
            return "друга"
        }

        return "друзей"
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
}
