//
//  SearchFriendCell.swift
//  Stepmates Auth
//
//  Created by Диана on 17/03/2026.
//

import UIKit

protocol SearchFriendCellDelegate: AnyObject {
    func onUserTapped(_ user: AccessUsers)
    func onActionTapped(_ user: AccessUsers)
}

final class SearchFriendCell: UITableViewCell {
    static let reuseId = "SearchFriendCell"
    
    private let avatarView = UIView.makeAvatarCircle(size: 28)
    
    private lazy var usernameButton = UIButton.makeSearchUsernameButton(
        target: self,
        action: #selector(onUsernameTapped)
    )
    
    private lazy var actionButton = UIButton.makeSearchResultActionButton(
        target: self,
        action: #selector(onActionButtonTapped)
    )
    
    private var user: AccessUsers?
    weak var delegate: SearchFriendCellDelegate?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }
}

private extension SearchFriendCell {
    func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        
        avatarView
            .addTo(contentView)
            .centerYOn(contentView)
            .pinLeft(toAnchor: contentView.leftAnchor, constant: 0)
            .setSize(width: 40, height: 40)
        
        usernameButton
            .addTo(contentView)
            .centerYOn(contentView)
            .pinLeft(toAnchor: avatarView.rightAnchor, constant: 10)
        
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
}

extension SearchFriendCell {
    func configure(with user: AccessUsers, delegate: SearchFriendCellDelegate?) {
        self.user = user
        self.delegate = delegate
        
        avatarView.backgroundColor = randomColor(for: user.username)
        usernameButton.setTitle(user.username, for: .normal)
        
        if user.isFriend {
            actionButton.setTitle("Уже друг", for: .normal)
            actionButton.backgroundColor = .clear
            actionButton.setTitleColor(.black, for: .normal)
            actionButton.isEnabled = false
            return
        }
        
        if user.requestSent {
            actionButton.setTitle("Запрос", for: .normal)
            actionButton.backgroundColor = Constants.orange ?? .orange
            actionButton.setTitleColor(.white, for: .normal)
            actionButton.isEnabled = false
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
