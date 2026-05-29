//
//  GroupsViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 21/02/2026.
//

import UIKit

protocol GroupsNavDelegate: AnyObject {
    func onBackFromGroups()
    func onCreateGroupTapped()
    func onGroupSelected(_ group: GroupListItem)
}

final class GroupsViewController: UIViewController {

    weak var navDelegate: GroupsNavDelegate?

    private let viewModel: ViewModel
    private var groups: [GroupListItem] = []
    private var isLoadingGroups = false
    private var lastGroupsLoadAt = Date.distantPast
    private let groupsReloadInterval: TimeInterval = 20


    private lazy var createGroupButton = UIButton.makeImageButton(
        imageName: "createGroupBtn",
        target: self,
        action: #selector(onCreateTapped)
    )

    private lazy var titleLabel = UILabel.makeManrope(
        text: "Группы",
        style: Constants.manropeExtraBold,
        size: 32,
        color: Constants.blue ?? .systemBlue
    )

    private lazy var emptyLabel = UILabel.makeManrope(
        text: "Вы не состоите ни в одной группе :(",
        style: Constants.manropeMedium,
        size: 18,
        color: .systemGray
    )

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 106
        tableView.register(GroupCell.self, forCellReuseIdentifier: GroupCell.reuseId)
        return tableView
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
extension GroupsViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        let cachedGroups = viewModel.cachedGroupsSnapshot()
        if cachedGroups.isEmpty == false {
            applyGroups(cachedGroups)
        } else {
            emptyLabel.isHidden = true
            tableView.isHidden = false
        }
        loadGroups()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadGroups(force: true)
    }
}

// MARK: - Setup
private extension GroupsViewController {

    func setupViews() {
        view.backgroundColor = .white

        refreshControl.addTarget(self, action: #selector(onRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        titleLabel
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: Constants.titleTop)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 16)

        createGroupButton
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: Constants.titleTop)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -16)
            .setSize(width: 32, height: 32)

        tableView
            .addTo(view)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 28)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 20)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -20)
            .pinBottom(toAnchor: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)

        emptyLabel.textAlignment = .center

        emptyLabel
            .addTo(view)
            .centerXOn(view)
            .centerYOn(view)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 20)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -20)
    }

    func applyGroups(_ result: [GroupListItem]) {
        groups = result
        AvatarLoader.shared.prefetch(urlStrings: result.compactMap(\.avatarUrl))
        tableView.reloadData()
        updateEmptyState()
    }

    func loadGroups(force: Bool = false) {
        guard isLoadingGroups == false else {
            refreshControl.endRefreshing()
            return
        }

        let elapsed = Date().timeIntervalSince(lastGroupsLoadAt)
        guard force || groups.isEmpty || elapsed >= groupsReloadInterval else {
            refreshControl.endRefreshing()
            return
        }

        isLoadingGroups = true
        Task { [weak self] in
            guard let self else { return }

            let result = await viewModel.getGroups()

            await MainActor.run {
                self.isLoadingGroups = false
                self.lastGroupsLoadAt = Date()
                self.applyGroups(result)
                self.refreshControl.endRefreshing()
            }
        }
    }

    func updateEmptyState() {
        let isEmpty = groups.isEmpty
        emptyLabel.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }
}

// MARK: - Actions
private extension GroupsViewController {


    @objc func onCreateTapped() {
        navDelegate?.onCreateGroupTapped()
    }

    @objc func onRefresh() {
        loadGroups(force: true)
    }
}

// MARK: - UITableView
extension GroupsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groups.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: GroupCell.reuseId,
            for: indexPath
        ) as? GroupCell else {
            return UITableViewCell()
        }

        cell.configure(
            with: groups[indexPath.row],
            index: indexPath.row
        )
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navDelegate?.onGroupSelected(groups[indexPath.row])
    }
}
