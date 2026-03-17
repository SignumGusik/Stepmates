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
    private let avatarView = UIView()
    private let usernameLabel = UILabel()
    private let stepsLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
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
        
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.layer.cornerRadius = 12
        avatarView.clipsToBounds = true
        
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.textColor = .black
        
        stepsLabel.translatesAutoresizingMaskIntoConstraints = false
        stepsLabel.textColor = .black
        stepsLabel.textAlignment = .right
        
        cardView.addTo(contentView)
            .pinTop(toAnchor: contentView.topAnchor, constant: 4)
            .pinLeft(toAnchor: contentView.leftAnchor, constant: 6)
            .pinBottom(toAnchor: contentView.bottomAnchor, constant: -4)
            .setHeight(48)
            .setWidth(338)
        
        placeContainerView
            .addTo(cardView)
            .centerYOn(cardView)
            .pinLeft(toAnchor: contentView.leftAnchor, constant: 6)
            .setWidth(48)
            .setHeight(53)
        
        placeLabel
            .addTo(placeContainerView)
            .centerXOn(placeContainerView)
            .centerYOn(placeContainerView)
            
        
        avatarView
            .addTo(cardView)
            .centerYOn(cardView)
            .pinLeft(toAnchor: placeContainerView.rightAnchor, constant: 12)
            .setSize(width: 24, height: 24)
        
        usernameLabel
            .addTo(cardView)
            .centerYOn(cardView)
            .pinLeft(toAnchor: avatarView.rightAnchor, constant: 8)
        
        stepsLabel
            .addTo(cardView)
            .centerYOn(cardView)
            .pinRight(toAnchor: cardView.rightAnchor, constant: -11)
    }
}

extension FriendLeaderboardCell {
    func configure(with item: FriendLeaderboardItem) {
        placeLabel.text = "\(item.place)"
        usernameLabel.text = item.username
        stepsLabel.text = Self.formatSteps(item.steps)
        avatarView.backgroundColor = item.avatarColor
        
        if item.place <= 3 {
            placeLabel.font = UIFont(name: Constants.manropeExtraBold, size: 24)
                ?? .systemFont(ofSize: 24, weight: .heavy)
        } else {
            placeLabel.font = UIFont(name: "MalgunGothic", size: 24)
                ?? .systemFont(ofSize: 24, weight: .regular)
        }
        
        usernameLabel.font = UIFont(name: Constants.manropeExtraBold, size: 16)
            ?? .systemFont(ofSize: 16, weight: .heavy)
        
        stepsLabel.font = UIFont(name: Constants.manropeExtraBold, size: 16)
            ?? .systemFont(ofSize: 16, weight: .heavy)
        
        if item.place == 1 {
            cardView.backgroundColor = Constants.orange?.withAlphaComponent(0.7)
            placeContainerView.backgroundColor = Constants.orange
        } else if item.place == 2 {
            cardView.backgroundColor = Constants.orange?.withAlphaComponent(0.5)
            placeContainerView.backgroundColor = Constants.orange?.withAlphaComponent(0.7)
        } else if item.place == 3 {
            cardView.backgroundColor = Constants.orange?.withAlphaComponent(0.4)
            placeContainerView.backgroundColor = Constants.orange?.withAlphaComponent(0.5)
        } else {
            cardView.backgroundColor = Constants.purple?.withAlphaComponent(0.4)
            placeContainerView.backgroundColor = Constants.purple?.withAlphaComponent(0.5)
        }
    }
    
    private static func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }
}
