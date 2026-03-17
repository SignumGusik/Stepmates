//
//  NotificationRequestCell.swift.swift
//  Stepmates Auth
//
//  Created by Диана on 12/02/2026.
//

import UIKit
import Foundation

class NotificationRequestCell: UITableViewCell {
    static let reuseId = "NotificationRequestCell"
    
    @objc var onAcceptTapped: (() -> Void)?
    @objc var onRejectTapped: (() -> Void)?
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private lazy var rejectButton = UIButton.makeCircleButton(systemName: "xmark", target: self, action: #selector(onReject))
    private lazy var acceptButton = UIButton.makeCircleButton(systemName: "checkmark", target: self, action: #selector(onAccept))
    private lazy var textStack = UIStackView.createTextStack(arrangedSubviews: [self.titleLabel, self.subtitleLabel])
    private lazy var buttonsStack = UIStackView.createButtonStack(arrangedSubviews: [self.rejectButton, self.acceptButton])
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        onAcceptTapped = nil
        onRejectTapped = nil
        setLoading(false)
    }
    
}

extension NotificationRequestCell {
    private func setupView() -> Void {
        selectionStyle = .none
        contentView.addSubview(textStack)
        contentView.addSubview(buttonsStack)
        NSLayoutConstraint.activate([
                textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                textStack.trailingAnchor.constraint(lessThanOrEqualTo: buttonsStack.leadingAnchor, constant: -12),

                buttonsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                buttonsStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

                contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
    }
    func setupActions() {
            rejectButton.addTarget(self, action: #selector(onReject), for: .touchUpInside)
            acceptButton.addTarget(self, action: #selector(onAccept), for: .touchUpInside)
        }
}

extension NotificationRequestCell {
    @objc func onReject() {
        onRejectTapped?()
    }

    @objc func onAccept() {
        onAcceptTapped?()
    }
}

extension NotificationRequestCell {
    func setLoading(_ isLoading: Bool) {
        rejectButton.isEnabled = !isLoading
        acceptButton.isEnabled = !isLoading

        rejectButton.alpha = isLoading ? 0.5 : 1
        acceptButton.alpha = isLoading ? 0.5 : 1
    }
    func configure(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
    
}
