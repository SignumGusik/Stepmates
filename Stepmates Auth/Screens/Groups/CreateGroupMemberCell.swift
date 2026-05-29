//
//  CreateGroupMemberCell.swift
//  Stepmates Auth
//
//  Created by Диана on 05/05/2026.
//

import UIKit

protocol CreateGroupMemberCellDelegate: AnyObject {
    func onDeleteMemberTapped(_ cell: CreateGroupMemberCell)
    func onMakeAdminTapped(_ cell: CreateGroupMemberCell)
}

final class CreateGroupMemberCell: UITableViewCell {

    static let reuseId = "CreateGroupMemberCell"

    weak var delegate: CreateGroupMemberCellDelegate?

    private var avatarTask: URLSessionDataTask?
    private var currentAvatarUrl: String?
    private let containerView = UIView()
    private let avatarView = UIView.makeAvatarImageView(size: 34)
    private var textRightToDeleteConstraint: NSLayoutConstraint?
    private var textRightToContainerConstraint: NSLayoutConstraint?

    private lazy var usernameLabel = UILabel.makeManrope(
        text: "",
        style: Constants.manropeExtraBold,
        size: 15,
        color: .black
    )

    private lazy var subtitleLabel = UILabel.makeManrope(
        text: "",
        style: Constants.manropeMedium,
        size: 8,
        color: .gray
    )

    private lazy var deleteButton = UIButton.makeImageButton(
        imageName: "deleteMemberBtn",
        target: self,
        action: #selector(onDeleteTapped)
    )

    private lazy var adminButton = UIButton.makeImageButton(
        imageName: "makeMemberAdminBtn",
        target: self,
        action: #selector(onAdminTapped)
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
        currentAvatarUrl = nil

        avatarView.image = nil
        avatarView.backgroundColor = .systemGray5
        usernameLabel.text = nil
        subtitleLabel.text = nil
    }

    func configure(
        with member: GroupDraftMember,
        isEditing: Bool = true,
        canEditThisMember: Bool = true
    ) {
        usernameLabel.text = member.username
        subtitleLabel.text = member.isAdmin ? "админ" : member.subtitle

        avatarView.image = nil
        avatarView.backgroundColor = member.avatarColor

        let shouldShowActions = isEditing && canEditThisMember

        deleteButton.isHidden = !shouldShowActions
        adminButton.isHidden = !shouldShowActions || member.isAdmin

        textRightToDeleteConstraint?.isActive = shouldShowActions
        textRightToContainerConstraint?.isActive = !shouldShowActions

        loadAvatarIfNeeded(for: member)
    }
    func loadAvatarIfNeeded(for member: GroupDraftMember) {
        guard let avatarUrl = member.avatarUrl, avatarUrl.isEmpty == false else {
            return
        }

        avatarTask?.cancel()
        currentAvatarUrl = avatarUrl

        avatarTask = AvatarLoader.shared.load(urlString: avatarUrl) { [weak self] image in
            guard let self else { return }
            guard self.currentAvatarUrl == avatarUrl else { return }

            if let image {
                self.avatarView.image = image
                self.avatarView.backgroundColor = .clear
            }
        }
    }
}

private extension CreateGroupMemberCell {

    func setupViews() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 18
        containerView.clipsToBounds = true

        containerView
            .addTo(contentView)
            .centerYOn(contentView)
            .pinLeft(toAnchor: contentView.leftAnchor, constant: 24)
            .pinRight(toAnchor: contentView.rightAnchor, constant: -24)
            .setHeight(48)

        avatarView
            .addTo(containerView)
            .centerYOn(containerView)
            .pinLeft(toAnchor: containerView.leftAnchor, constant: 10)
            .setSize(width: 34, height: 34)

        adminButton
            .addTo(containerView)
            .centerYOn(containerView)
            .pinRight(toAnchor: containerView.rightAnchor, constant: -18)
            .setSize(width: 22, height: 22)

        deleteButton
            .addTo(containerView)
            .centerYOn(containerView)
            .pinRight(toAnchor: adminButton.leftAnchor, constant: -16)
            .setSize(width: 22, height: 22)

        usernameLabel
            .addTo(containerView)
            .pinTop(toAnchor: containerView.topAnchor, constant: 8)
            .pinLeft(toAnchor: avatarView.rightAnchor, constant: 8)

        subtitleLabel
            .addTo(containerView)
            .pinTop(toAnchor: usernameLabel.bottomAnchor, constant: -1)
            .pinLeft(toAnchor: avatarView.rightAnchor, constant: 8)

        textRightToDeleteConstraint = usernameLabel.rightAnchor.constraint(
            equalTo: deleteButton.leftAnchor,
            constant: -8
        )

        textRightToContainerConstraint = usernameLabel.rightAnchor.constraint(
            equalTo: containerView.rightAnchor,
            constant: -16
        )

        subtitleLabel.rightAnchor.constraint(
            lessThanOrEqualTo: containerView.rightAnchor,
            constant: -16
        ).isActive = true

        textRightToDeleteConstraint?.isActive = true

    }

    @objc func onDeleteTapped() {
        delegate?.onDeleteMemberTapped(self)
    }

    @objc func onAdminTapped() {
        delegate?.onMakeAdminTapped(self)
    }
}
