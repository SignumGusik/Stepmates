//
//  LeaderboardPeriodDropdownView.swift
//  Stepmates Auth
//
//  Created by Диана on 21/04/2026.
//

import UIKit

protocol LeaderboardPeriodDropdownViewDelegate: AnyObject {
    func onDropdownTapped()
}

final class LeaderboardPeriodDropdownView: UIView {

    weak var delegate: LeaderboardPeriodDropdownViewDelegate?

    private let button = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let chevron = UIImageView()

    private var isExpanded: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }

    func setTitle(_ title: String) {
        titleLabel.text = title
    }

    func setExpanded(_ expanded: Bool, animated: Bool = true) {
        isExpanded = expanded

        let angle: CGFloat = expanded ? .pi : 0
        let animations = { [weak self] in
            guard let self else { return }
            self.chevron.transform = CGAffineTransform(rotationAngle: angle)
            self.button.transform = expanded ? CGAffineTransform(scaleX: 0.99, y: 0.99) : .identity
        }

        if animated {
            UIView.animate(withDuration: 0.22,
                           delay: 0,
                           options: [.curveEaseInOut],
                           animations: animations)
        } else {
            animations()
        }
    }
}

private extension LeaderboardPeriodDropdownView {

    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        // pill button
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.layer.cornerRadius = 18
        button.clipsToBounds = true
        button.layer.borderWidth = 2
        button.layer.borderColor = (Constants.blue ?? .systemBlue).cgColor
        button.addTarget(self, action: #selector(onTap), for: .touchUpInside)

        // title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.textColor = Constants.blue ?? .systemBlue
        titleLabel.font = UIFont(name: Constants.manropeExtraBold, size: 18)
            ?? .systemFont(ofSize: 18, weight: .bold)

        // chevron
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.contentMode = .scaleAspectFit
        chevron.image = UIImage(systemName: "chevron.down")?.withRenderingMode(.alwaysTemplate)
        chevron.tintColor = Constants.blue ?? .systemBlue

        button
            .addTo(self)
            .pinTop(toAnchor: topAnchor, constant: 0)
            .pinLeft(toAnchor: leftAnchor, constant: 0)
            .pinRight(toAnchor: rightAnchor, constant: 0)
            .pinBottom(toAnchor: bottomAnchor, constant: 0)
            .setHeight(36)

        titleLabel
            .addTo(button)
            .centerYOn(button)
            .centerXOn(button)

        chevron
            .addTo(button)
            .centerYOn(button)
            .pinRight(toAnchor: button.rightAnchor, constant: -14)
            .setSize(width: 14, height: 14)

        setExpanded(false, animated: false)
    }

    @objc func onTap() {
        delegate?.onDropdownTapped()
    }
}
