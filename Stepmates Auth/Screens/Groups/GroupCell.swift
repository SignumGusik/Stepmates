//
//  GroupCell.swift
//  Stepmates Auth
//
//  Created by Диана on 05/05/2026.
//

import UIKit

final class GroupCell: UITableViewCell {

    static let reuseId = "GroupCell"

    private var avatarTask: URLSessionDataTask?

    private let containerView = UIView()
    private let avatarImageView = UIView.makeAvatarImageView(size: 56)

    private lazy var titleLabel = UILabel.makeManrope(
        text: "",
        style: Constants.manropeExtraBold,
        size: 18,
        color: .black
    )

    private lazy var membersLabel = UILabel.makeManrope(
        text: "",
        style: Constants.manropeMedium,
        size: 14,
        color: .black
    )

    private lazy var placeLabel = UILabel.makeManrope(
        text: "",
        style: Constants.manropeMedium,
        size: 14,
        color: .systemGray
    )

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        avatarTask?.cancel()
        avatarTask = nil

        avatarImageView.image = nil
        avatarImageView.backgroundColor = .systemGray5

        titleLabel.text = nil
        membersLabel.text = nil
        placeLabel.text = nil
    }

    func configure(with item: GroupListItem, index: Int) {
        containerView.backgroundColor = index % 2 == 0
            ? Constants.lightPurple
            : UIColor(hex: "#FFE0CA")

        titleLabel.text = item.name
        membersLabel.text = "\(item.membersCount) участника(ов)"

        if let myPlace = item.myPlace, item.membersCount > 0 {
            placeLabel.text = "Вы на \(myPlace) месте из \(item.membersCount)"
        } else {
            placeLabel.text = "Место пока не определено"
        }

        avatarImageView.backgroundColor = UIColor.white.withAlphaComponent(0.55)
        loadAvatarIfNeeded(item.avatarUrl)
    }
}

private extension GroupCell {

    func setupViews() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer.cornerRadius = 22
        containerView.clipsToBounds = true

        containerView
            .addTo(contentView)
            .centerYOn(contentView)
            .pinLeft(toAnchor: contentView.leftAnchor, constant: 0)
            .pinRight(toAnchor: contentView.rightAnchor, constant: 0)
            .setHeight(94)

        avatarImageView
            .addTo(containerView)
            .centerYOn(containerView)
            .pinLeft(toAnchor: containerView.leftAnchor, constant: 20)
            .setSize(width: 56, height: 56)

        titleLabel
            .addTo(containerView)
            .pinTop(toAnchor: containerView.topAnchor, constant: 14)
            .pinLeft(toAnchor: avatarImageView.rightAnchor, constant: 16)
            .pinRight(toAnchor: containerView.rightAnchor, constant: -18)

        membersLabel
            .addTo(containerView)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 3)
            .pinLeft(toAnchor: avatarImageView.rightAnchor, constant: 16)
            .pinRight(toAnchor: containerView.rightAnchor, constant: -18)

        placeLabel
            .addTo(containerView)
            .pinTop(toAnchor: membersLabel.bottomAnchor, constant: 1)
            .pinLeft(toAnchor: avatarImageView.rightAnchor, constant: 16)
            .pinRight(toAnchor: containerView.rightAnchor, constant: -18)
    }

    func loadAvatarIfNeeded(_ avatarUrl: String?) {
        guard
            let avatarUrl,
            let url = URL(string: avatarUrl)
        else {
            return
        }

        avatarTask?.cancel()

        avatarTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard
                let self,
                let data,
                let image = UIImage(data: data)
            else {
                return
            }

            DispatchQueue.main.async {
                self.avatarImageView.image = image
                self.avatarImageView.backgroundColor = .clear
            }
        }

        avatarTask?.resume()
    }
}
