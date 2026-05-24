//
//  MapScopeChipsView.swift
//  Stepmates Auth
//

import UIKit

final class MapScopeChipsView: UIView {

    var onAllFriendsTap: (() -> Void)?
    var onGroupTap: ((MapGroupDTO) -> Void)?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private var groups: [MapGroupDTO] = []
    private var selectedScope: MapScope = .allFriends

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(groups: [MapGroupDTO], selectedScope: MapScope) {
        self.groups = groups
        self.selectedScope = selectedScope
        render()
    }
}

private extension MapScopeChipsView {

    func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 22, bottom: 0, right: 22)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.alignment = .center

        addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        render()
    }

    func render() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let allButton = makeScopeButton(
            title: "все друзья",
            selected: selectedScope == .allFriends
        )
        allButton.addTarget(self, action: #selector(onAllFriendsButtonTapped), for: .touchUpInside)
        stackView.addArrangedSubview(allButton)

        for group in groups {
            let button = makeScopeButton(
                title: group.name,
                selected: selectedScope == .group(id: group.id, name: group.name)
            )

            button.tag = group.id
            button.addTarget(self, action: #selector(onGroupButtonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
    }

    func makeScopeButton(title: String, selected: Bool) -> UIButton {
        let button = UIButton(type: .system)

        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont(name: Constants.manropeMedium, size: 16)
            ?? UIFont.systemFont(ofSize: 16, weight: .medium)
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.85

        button.layer.cornerRadius = 17
        button.layer.masksToBounds = false

        button.backgroundColor = selected
            ? (Constants.purple ?? .systemBlue)
            : UIColor.white.withAlphaComponent(0.96)

        button.setTitleColor(selected ? .white : .black, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)

        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = selected ? 0.13 : 0.08
        button.layer.shadowRadius = 8
        button.layer.shadowOffset = CGSize(width: 0, height: 4)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 128),
            button.heightAnchor.constraint(equalToConstant: 34)
        ])

        return button
    }

    @objc func onAllFriendsButtonTapped() {
        onAllFriendsTap?()
    }

    @objc func onGroupButtonTapped(_ sender: UIButton) {
        guard let group = groups.first(where: { $0.id == sender.tag }) else { return }
        onGroupTap?(group)
    }
}
