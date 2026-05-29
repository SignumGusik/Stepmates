//
//  NotificationsViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 06/02/2026.
//

import UIKit

final class NotificationsViewController: UIViewController {

    private let viewModel: ViewModel
    private var items: [AppNotificationDTO] = []
    private var isLoadingNotifications = false
    private var lastNotificationsLoadAt = Date.distantPast
    private let notificationsReloadInterval: TimeInterval = 20

    private lazy var titleLabel = UILabel.makeManrope(
        text: "Уведомления",
        style: Constants.manropeExtraBold,
        size: 32,
        color: Constants.blue ?? .systemBlue
    )

    private lazy var emptyLabel = UILabel.makeManrope(
        text: "Новых уведомлений пока нет",
        style: Constants.manropeMedium,
        size: 18,
        color: .systemGray
    )

    private lazy var tableView: UITableView = {
        let table = UITableView.makeLeaderboardTable(dataSource: self, delegate: self)
        table.register(NotificationRequestCell.self, forCellReuseIdentifier: NotificationRequestCell.reuseId)
        table.rowHeight = 64
        table.separatorStyle = .none
        table.backgroundColor = .clear
        return table
    }()

    private let refreshControl = UIRefreshControl()

    required init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }
}

// MARK: - Lifecycle
extension NotificationsViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        applyCachedNotificationsIfAvailable()
        loadNotifications()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadNotifications()
    }
}

// MARK: - Setup
private extension NotificationsViewController {

    func setupViews() {
        view.backgroundColor = .white

        refreshControl.addTarget(self, action: #selector(onRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        titleLabel
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: Constants.titleTop)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 16)

        tableView
            .addTo(view)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 25)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor)
            .pinBottom(toAnchor: view.safeAreaLayoutGuide.bottomAnchor)

        emptyLabel.textAlignment = .center

        emptyLabel
            .addTo(view)
            .centerXOn(view)
            .centerYOn(view)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 20)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -20)
    }

    func applyCachedNotificationsIfAvailable() {
        let cached = viewModel.cachedNotificationsSnapshot()
        guard cached.isEmpty == false else { return }
        applyNotifications(cached)
    }

    func loadNotifications(force: Bool = false) {
        guard isLoadingNotifications == false else {
            refreshControl.endRefreshing()
            return
        }

        let elapsed = Date().timeIntervalSince(lastNotificationsLoadAt)
        guard force || elapsed >= notificationsReloadInterval else {
            refreshControl.endRefreshing()
            return
        }

        isLoadingNotifications = true

        Task { [weak self] in
            guard let self else { return }

            do {
                let result = try await viewModel.getNotifications(force: force)

                await MainActor.run {
                    self.isLoadingNotifications = false
                    self.lastNotificationsLoadAt = Date()
                    self.applyNotifications(result)
                    self.refreshControl.endRefreshing()
                }
            } catch {
                await MainActor.run {
                    self.isLoadingNotifications = false
                    self.lastNotificationsLoadAt = Date()
                    self.refreshControl.endRefreshing()
                    if self.items.isEmpty {
                        self.showOkAlert(title: "Ошибка", message: self.serverMessage(from: error))
                    }
                }
            }
        }
    }

    func applyNotifications(_ notifications: [AppNotificationDTO]) {
        items = notifications
        tableView.reloadData()
        updateEmptyState()
    }

    func updateEmptyState() {
        let isEmpty = items.isEmpty
        emptyLabel.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }
}

// MARK: - Actions
private extension NotificationsViewController {

    @objc func onRefresh() {
        loadNotifications(force: true)
    }

    func accept(item: AppNotificationDTO) {
        Task { [weak self] in
            guard let self else { return }

            do {
                switch item.type {
                case .friendRequest:
                    try await viewModel.acceptFriendRequest(id: item.id)

                case .groupInvite:
                    try await viewModel.acceptGroupInvite(id: item.id)

                case .friendRequestAccepted:
                    try await viewModel.dismissFriendAcceptedNotification(id: item.id)
                }

                await MainActor.run {
                    self.items.removeAll { $0.id == item.id && $0.type == item.type }
                    self.viewModel.saveNotificationsSnapshot(self.items)
                    self.tableView.reloadData()
                    self.updateEmptyState()
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(title: "Ошибка", message: self.serverMessage(from: error))
                }
            }
        }
    }

    func reject(item: AppNotificationDTO) {
        Task { [weak self] in
            guard let self else { return }

            do {
                switch item.type {
                case .friendRequest:
                    try await viewModel.rejectFriendRequest(id: item.id)

                case .groupInvite:
                    try await viewModel.rejectGroupInvite(id: item.id)

                case .friendRequestAccepted:
                    return
                }

                await MainActor.run {
                    self.items.removeAll { $0.id == item.id && $0.type == item.type }
                    self.viewModel.saveNotificationsSnapshot(self.items)
                    self.tableView.reloadData()
                    self.updateEmptyState()
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(title: "Ошибка", message: self.serverMessage(from: error))
                }
            }
        }
    }

    func serverMessage(from error: Error) -> String {
        if case let NetworkError.failedStatusCodeResponseData(_, data) = error,
           let text = String(data: data, encoding: .utf8) {
            return text
        }

        return error.localizedDescription
    }
}

// MARK: - UITableViewDataSource
extension NotificationsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: NotificationRequestCell.reuseId,
            for: indexPath
        ) as? NotificationRequestCell else {
            return UITableViewCell()
        }

        let item = items[indexPath.row]

        cell.configure(with: item)

        cell.onAcceptTapped = { [weak self] in
            self?.accept(item: item)
        }

        cell.onRejectTapped = { [weak self] in
            self?.reject(item: item)
        }

        return cell
    }
}
