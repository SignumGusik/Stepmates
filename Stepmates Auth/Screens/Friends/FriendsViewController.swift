//
//  FriendsViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 02/02/2026.
//

import UIKit

protocol FriendsNavDelegate: AnyObject {
    func onSearchFriendsTapped()
    func onUserSelected(_ user: AccessUsers, source: SelectedUserProfileSource, isOwnProfile: Bool)
}

final class FriendsViewController: UIViewController {

    enum LeaderboardPeriod: String, CaseIterable {
        case today = "today"
        case week = "week"
        case month = "month"

        var title: String {
            switch self {
            case .today: return "За сегодня"
            case .week: return "За неделю"
            case .month: return "За месяц"
            }
        }
    }

    weak var navDelegate: FriendsNavDelegate?

    private lazy var addButton = UIButton.makeImageButton(
        imageName: "addFriendsBtn",
        target: self,
        action: #selector(onAddTapped)
    )

    private lazy var titleLabel = UILabel.makeManrope(
        text: "Друзья",
        style: Constants.manropeExtraBold,
        size: 32,
        color: Constants.blue ?? .systemBlue
    )

    private let underlineView = UIView()

    private lazy var ratingLabel = UILabel.makeManrope(
        text: "Рейтинг:",
        style: Constants.manropeExtraBold,
        size: 20,
        color: Constants.blue ?? .systemBlue
    )

    private let periodView = LeaderboardPeriodDropdownView()

    private lazy var tableView = UITableView.makeLeaderboardTable(
        dataSource: self,
        delegate: self
    )

    private let refreshControl = UIRefreshControl()
    private var items: [FriendLeaderboardItem] = []
    private let viewModel: ViewModel
    private var previousPlacesByUserID: [Int: Int] = [:]

    private var selectedPeriod: LeaderboardPeriod = .today
    private let dropdownOverlay = UIControl()
    private let dropdownTable = UITableView(frame: .zero, style: .plain)
    private var dropdownHeightConstraint: NSLayoutConstraint?
    private var isDropdownOpen: Bool = false

    private let dropdownRowHeight: CGFloat = 44
    private var dropdownMaxHeight: CGFloat {
        CGFloat(LeaderboardPeriod.allCases.count) * dropdownRowHeight
    }

    required init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }
}

// MARK: - Lifecycle
extension FriendsViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupDropdown()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }
}

// MARK: - Setup
private extension FriendsViewController {

    func setupViews() {
        view.backgroundColor = .white

        underlineView.translatesAutoresizingMaskIntoConstraints = false
        underlineView.backgroundColor = Constants.blue ?? .systemBlue

        periodView.delegate = self
        periodView.setTitle(selectedPeriod.title)
        periodView.setExpanded(false, animated: false)

        tableView.register(FriendLeaderboardCell.self, forCellReuseIdentifier: FriendLeaderboardCell.reuseId)
        tableView.rowHeight = 68
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear

        refreshControl.addTarget(self, action: #selector(onRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        addButton
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: Constants.titleTop)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -16)
            .setSize(width: 32, height: 32)

        titleLabel
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: Constants.titleTop)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 16)

        underlineView
            .addTo(view)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 10)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 16)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -16)
            .setHeight(2)

        ratingLabel
            .addTo(view)
            .pinTop(toAnchor: underlineView.bottomAnchor, constant: 18)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 16)

        periodView
            .addTo(view)
            .pinTop(toAnchor: ratingLabel.bottomAnchor, constant: 10)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 16)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -16)

        tableView
            .addTo(view)
            .pinTop(toAnchor: periodView.bottomAnchor, constant: 12)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 0)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: 0)
            .pinBottom(toAnchor: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
    }

    private func setupDropdown() {
        dropdownOverlay.translatesAutoresizingMaskIntoConstraints = false
        dropdownOverlay.backgroundColor = (Constants.grey ?? .systemGray5).withAlphaComponent(0.4)
        dropdownOverlay.alpha = 0
        dropdownOverlay.isHidden = true
        dropdownOverlay.addTarget(self, action: #selector(onOverlayTapped), for: .touchUpInside)

        dropdownOverlay
            .addTo(view)
            .pinTop(toAnchor: view.topAnchor, constant: 0)
            .pinLeft(toAnchor: view.leftAnchor, constant: 0)
            .pinRight(toAnchor: view.rightAnchor, constant: 0)
            .pinBottom(toAnchor: view.bottomAnchor, constant: 0)
        view.bringSubviewToFront(dropdownOverlay)
        dropdownTable.translatesAutoresizingMaskIntoConstraints = false
        dropdownTable.backgroundColor = .white
        dropdownTable.layer.cornerRadius = 18
        dropdownTable.clipsToBounds = true
        dropdownTable.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        dropdownTable.rowHeight = dropdownRowHeight
        dropdownTable.isScrollEnabled = false
        dropdownTable.dataSource = self
        dropdownTable.delegate = self
        dropdownTable.register(UITableViewCell.self, forCellReuseIdentifier: "PeriodCell")

        dropdownTable.layer.borderWidth = 2
        dropdownTable.layer.borderColor = (Constants.blue ?? .systemBlue).cgColor

        dropdownTable
            .addTo(dropdownOverlay)
            .pinTop(toAnchor: periodView.bottomAnchor, constant: 8)
            .pinLeft(toAnchor: periodView.leftAnchor, constant: 0)
            .pinRight(toAnchor: periodView.rightAnchor, constant: 0)
        dropdownHeightConstraint?.isActive = false
        dropdownHeightConstraint = dropdownTable.heightAnchor.constraint(equalToConstant: 0)
        dropdownHeightConstraint?.isActive = true
    }

    func loadData(isRefreshing: Bool = false) {
        Task { [weak self] in
            guard let self else { return }
            let result = await viewModel.getLeaderboardItems(period: selectedPeriod)

            await MainActor.run {
                let movedUpUserIds = Set(
                    result.compactMap { item -> Int? in
                        guard let previousPlace = self.previousPlacesByUserID[item.userId],
                              previousPlace > item.place else {
                            return nil
                        }

                        return item.userId
                    }
                )

                AvatarLoader.shared.prefetch(urlStrings: result.compactMap(\.avatarUrl))
                self.items = result
                self.tableView.reloadData()
                self.previousPlacesByUserID = Dictionary(
                    uniqueKeysWithValues: result.map { ($0.userId, $0.place) }
                )
                self.animateMovedUpRows(userIds: movedUpUserIds)
                self.refreshControl.endRefreshing()
            }
        }
    }

    func animateMovedUpRows(userIds: Set<Int>) {
        guard userIds.isEmpty == false else { return }

        for indexPath in tableView.indexPathsForVisibleRows ?? [] {
            guard indexPath.row < items.count,
                  userIds.contains(items[indexPath.row].userId),
                  let cell = tableView.cellForRow(at: indexPath) else {
                continue
            }

            cell.contentView.transform = CGAffineTransform(translationX: 0, y: 12)
            cell.contentView.alpha = 0.76

            UIView.animate(
                withDuration: 0.28,
                delay: 0.02 * Double(indexPath.row),
                usingSpringWithDamping: 0.78,
                initialSpringVelocity: 0.6,
                options: [.curveEaseOut, .beginFromCurrentState]
            ) {
                cell.contentView.transform = .identity
                cell.contentView.alpha = 1
            }
        }
    }
}

// MARK: - Dropdown animation
private extension FriendsViewController {

    func showDropdown() {
        guard isDropdownOpen == false else { return }
        isDropdownOpen = true

        dropdownOverlay.isHidden = false
        dropdownOverlay.alpha = 0
        dropdownHeightConstraint?.constant = 0
        view.layoutIfNeeded()

        periodView.setExpanded(true, animated: true)
        dropdownTable.reloadData()

        if let idx = LeaderboardPeriod.allCases.firstIndex(of: selectedPeriod) {
            let ip = IndexPath(row: idx, section: 0)
            dropdownTable.selectRow(at: ip, animated: false, scrollPosition: .none)
        }

        dropdownHeightConstraint?.constant = dropdownMaxHeight

        UIView.animate(withDuration: 0.24,
                       delay: 0,
                       options: [.curveEaseInOut]) {
            self.dropdownOverlay.alpha = 1
            self.view.layoutIfNeeded()
        }
    }

    func hideDropdown() {
        guard isDropdownOpen else { return }
        isDropdownOpen = false

        periodView.setExpanded(false, animated: true)
        dropdownHeightConstraint?.constant = 0

        UIView.animate(withDuration: 0.22,
                       delay: 0,
                       options: [.curveEaseInOut]) {
            self.dropdownOverlay.alpha = 0
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.dropdownOverlay.isHidden = true
        }
    }

    @objc func onOverlayTapped() {
        hideDropdown()
    }
}

// MARK: - Actions
extension FriendsViewController {

    @objc func onAddTapped() {
        navDelegate?.onSearchFriendsTapped()
    }

    @objc func onRefresh() {
        loadData(isRefreshing: true)
    }
}

// MARK: - Dropdown delegate
extension FriendsViewController: LeaderboardPeriodDropdownViewDelegate {

    func onDropdownTapped() {
        isDropdownOpen ? hideDropdown() : showDropdown()
    }
}

// MARK: - UITableView
extension FriendsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView === dropdownTable {
            return LeaderboardPeriod.allCases.count
        }
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView === dropdownTable {
            let cell = tableView.dequeueReusableCell(withIdentifier: "PeriodCell", for: indexPath)
            let period = LeaderboardPeriod.allCases[indexPath.row]
            var config = cell.defaultContentConfiguration()
            config.text = period.title
            config.textProperties.font = UIFont(name: Constants.manropeExtraBold, size: 16)
                ?? .systemFont(ofSize: 16, weight: .bold)
            config.textProperties.color = Constants.blue ?? .systemBlue
            cell.contentConfiguration = config
            cell.backgroundColor = .white
            cell.contentView.backgroundColor = .white
            let selectedBg = UIView()
            selectedBg.backgroundColor = (Constants.grey ?? .systemGray5).withAlphaComponent(0.35)
            cell.selectedBackgroundView = selectedBg
            let highlightBg = UIView()
            highlightBg.backgroundColor = (Constants.grey ?? .systemGray5).withAlphaComponent(0.25)
            cell.backgroundView = highlightBg
            cell.selectionStyle = .default
            cell.tintColor = Constants.blue ?? .systemBlue
            return cell
        }

        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: FriendLeaderboardCell.reuseId,
            for: indexPath
        ) as? FriendLeaderboardCell else {
            return UITableViewCell()
        }

        cell.configure(with: items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView === dropdownTable {
            tableView.deselectRow(at: indexPath, animated: true)

            let period = LeaderboardPeriod.allCases[indexPath.row]
            selectedPeriod = period
            periodView.setTitle(period.title)

            hideDropdown()
            loadData()
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        if isDropdownOpen { return }

        let item = items[indexPath.row]

        let user = AccessUsers(
            id: item.userId,
            username: item.username,
            email: "",
            firstName: "",
            lastName: "",
            isFriend: true,
            requestSent: false,
            requestReceived: false,
            avatarUrl: item.avatarUrl
        )

        navDelegate?.onUserSelected(user, source: .leaderboard, isOwnProfile: item.isCurrentUser)
    }
}
