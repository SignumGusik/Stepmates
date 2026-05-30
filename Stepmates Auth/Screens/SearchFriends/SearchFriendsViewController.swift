//
//  SearchFriendsViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 02/02/2026.
//

import UIKit

protocol SearchFriendsNavDelegate: AnyObject {
    func onCloseSearchTapped()
    func onUserSelected(_ user: AccessUsers, source: SelectedUserProfileSource)
    func onGroupMemberSelected(_ user: AccessUsers)
}

final class SearchFriendsViewController: UIViewController {
    
    enum Mode {
        case friendsSearch
        case groupMemberSearch(selectedUserIds: Set<Int>)
    }
    private let mode: Mode

    private var titleText: String {
        switch mode {
        case .friendsSearch:
            return "Найди друзей"
        case .groupMemberSearch:
            return "Добавить участников"
        }
    }
    
    private lazy var titleLabel = UILabel.makeManrope(
        text: titleText,
        style: Constants.manropeExtraBold,
        size: 32,
        color: Constants.blue ?? .systemBlue
    )

    private let searchContainer = UIView.makeSearchBarContainer()
    private let searchIconView = UIImageView.makeSearchIcon()

    private lazy var clearButton = UIButton.makeSearchClearButton(
        target: self,
        action: #selector(onClearTapped)
    )

    private lazy var searchTextField = UITextField.makeSearchTextField(
        target: self,
        action: #selector(onSearchTextChanged)
    )

    private lazy var cancelButton = UIButton.makeSearchCancelButton(
        target: self,
        action: #selector(onCancelTapped)
    )

    private lazy var tableView = UITableView.makeUsersTable(
        dataSource: self,
        delegate: self
    )

    private var filteredUsers = [AccessUsers]()
    private let viewModel: ViewModel
    weak var navDelegate: SearchFriendsNavDelegate?

    private var searchTopConstraint: NSLayoutConstraint?
    private var cancelButtonWidthConstraint: NSLayoutConstraint?
    private var isSearchActive = false

    required init(
        viewModel: ViewModel,
        mode: Mode = .friendsSearch
    ) {
        self.viewModel = viewModel
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }
}

// MARK: - Lifecycle
extension SearchFriendsViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        searchTextField.delegate = self
        tableView.register(SearchFriendCell.self, forCellReuseIdentifier: SearchFriendCell.reuseId)
        tableView.rowHeight = 44
        loadInitialData()
    }
}

// MARK: - Setup
private extension SearchFriendsViewController {
    func setupViews() {
        applyStepmatesBaseScreen(backgroundColor: Constants.beige ?? .systemGroupedBackground)

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = 40

        layoutScreenTitle(titleLabel)

        searchContainer.addTo(view)
        searchTopConstraint = searchContainer.topAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.topAnchor,
            constant: 78
        )
        searchTopConstraint?.isActive = true

        searchContainer
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 16)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -16)
            .setHeight(50)

        searchIconView
            .addTo(searchContainer)
            .centerYOn(searchContainer)
            .pinLeft(toAnchor: searchContainer.leftAnchor, constant: 16)
            .setSize(width: 16, height: 16)

        cancelButton
            .addTo(searchContainer)
            .centerYOn(searchContainer)
            .pinRight(toAnchor: searchContainer.rightAnchor)
            .setHeight(50)
            .setWidth(70)

        cancelButtonWidthConstraint = cancelButton.widthAnchor.constraint(equalToConstant: 0)
        cancelButtonWidthConstraint?.isActive = true

        clearButton
            .addTo(searchContainer)
            .centerYOn(searchContainer)
            .pinRight(toAnchor: cancelButton.leftAnchor, constant: -8)
            .setSize(width: 16, height: 16)

        searchTextField
            .addTo(searchContainer)
            .centerYOn(searchContainer)
            .pinLeft(toAnchor: searchIconView.rightAnchor, constant: 8)
            .pinRight(toAnchor: clearButton.leftAnchor, constant: -8)

        layoutTableView(
            tableView,
            below: searchContainer.bottomAnchor,
            topSpacing: 12,
            horizontalInset: 16
        )
    }
    
    func loadInitialData() {
        switch mode {
        case .friendsSearch:
            return

        case .groupMemberSearch:
            performSearch()
        }
    }

    func setSearchActive(_ active: Bool, animated: Bool) {
        isSearchActive = active

        searchTopConstraint?.constant = active ? 10 : 78
        cancelButtonWidthConstraint?.constant = active ? 70 : 0

        let hasText = !(searchTextField.text ?? "").isEmpty

        let changes = {
            self.titleLabel.alpha = active ? 0 : 1
            self.cancelButton.alpha = active ? 1 : 0
            self.clearButton.alpha = (active && hasText) ? 1 : 0
            self.view.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
                changes()
            }
        } else {
            changes()
        }
    }

    func performSearch() {
        let text = searchTextField.text ?? ""

        Task { [weak self] in
            guard let self else { return }

            let result: [AccessUsers]

            switch self.mode {
            case .friendsSearch:
                result = await self.viewModel.getSearchFriends(query: text)

            case .groupMemberSearch(let selectedUserIds):
                result = await self.viewModel.getFriendsForGroupMemberSearch(
                    query: text,
                    selectedUserIds: selectedUserIds
                )
            }

            await MainActor.run {
                self.filteredUsers = result
                self.tableView.reloadData()
            }
        }
    }

    func updateUserState(
        userId: Int,
        isFriend: Bool,
        requestSent: Bool,
        requestReceived: Bool
    ) {
        guard let index = filteredUsers.firstIndex(where: { $0.id == userId }) else { return }
        filteredUsers[index].isFriend = isFriend
        filteredUsers[index].requestSent = requestSent
        filteredUsers[index].requestReceived = requestReceived
    }

    func showCancelRequestAlert(for user: AccessUsers) {
        let alert = UIAlertController(
            title: "Отменить запрос?",
            message: "Хотите отменить запрос в друзья?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Нет", style: .cancel))

        alert.addAction(UIAlertAction(title: "Да", style: .destructive) { [weak self] _ in
            guard let self else { return }

            Task {
                do {
                    try await self.viewModel.cancelFriendRequest(user)

                    await MainActor.run {
                        self.updateUserState(
                            userId: user.id,
                            isFriend: false,
                            requestSent: false,
                            requestReceived: false
                        )
                        self.tableView.reloadData()
                    }
                } catch {
                    await MainActor.run {
                        self.showOkAlert(title: "Ошибка", message: error.localizedDescription)
                    }
                }
            }
        })

        present(alert, animated: true)
    }

    func showRemoveFriendAlert(for user: AccessUsers) {
        let alert = UIAlertController(
            title: "Удалить из друзей?",
            message: "Хотите удалить пользователя из друзей?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Нет", style: .cancel))

        alert.addAction(UIAlertAction(title: "Да", style: .destructive) { [weak self] _ in
            guard let self else { return }

            Task {
                do {
                    try await self.viewModel.removeFromFriends(user)

                    await MainActor.run {
                        self.updateUserState(
                            userId: user.id,
                            isFriend: false,
                            requestSent: false,
                            requestReceived: false
                        )
                        self.tableView.reloadData()
                    }
                } catch {
                    await MainActor.run {
                        self.showOkAlert(title: "Ошибка", message: error.localizedDescription)
                    }
                }
            }
        })

        present(alert, animated: true)
    }
}

// MARK: - Actions
private extension SearchFriendsViewController {
    @objc func onCancelTapped() {
        searchTextField.text = ""
        searchTextField.resignFirstResponder()
        setSearchActive(false, animated: true)

        switch mode {
        case .friendsSearch:
            filteredUsers = []
            tableView.reloadData()

        case .groupMemberSearch:
            performSearch()
        }
    }

    @objc func onClearTapped() {
        searchTextField.text = ""
        clearButton.alpha = 0

        switch mode {
        case .friendsSearch:
            filteredUsers = []
            tableView.reloadData()

        case .groupMemberSearch:
            performSearch()
        }
    }

    @objc func onSearchTextChanged() {
        let text = searchTextField.text ?? ""
        clearButton.alpha = (isSearchActive && !text.isEmpty) ? 1 : 0
        performSearch()
    }
}

// MARK: - UITextFieldDelegate
extension SearchFriendsViewController: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        setSearchActive(true, animated: true)
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        performSearch()
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - TableView
extension SearchFriendsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredUsers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: SearchFriendCell.reuseId,
            for: indexPath
        ) as? SearchFriendCell else {
            return UITableViewCell()
        }

        let user = filteredUsers[indexPath.row]
        switch mode {
        case .friendsSearch:
            cell.configure(with: user, delegate: self, mode: .friendsSearch)

        case .groupMemberSearch(let selectedUserIds):
            cell.configure(
                with: user,
                delegate: self,
                mode: .groupMemberSearch(isSelected: selectedUserIds.contains(user.id))
            )
        }
        return cell
    }
}

extension SearchFriendsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let user = filteredUsers[indexPath.row]

        switch mode {
        case .friendsSearch:
            navDelegate?.onUserSelected(user, source: .search)

        case .groupMemberSearch(let selectedUserIds):
            guard !selectedUserIds.contains(user.id) else {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }

            navDelegate?.onGroupMemberSelected(user)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - SearchFriendCellDelegate
extension SearchFriendsViewController: SearchFriendCellDelegate {
    func onUserTapped(_ user: AccessUsers) {
        navDelegate?.onUserSelected(user, source: .search)
    }

    func onActionTapped(_ user: AccessUsers) {
        switch mode {
        case .groupMemberSearch(let selectedUserIds):
            guard !selectedUserIds.contains(user.id) else { return }
            navDelegate?.onGroupMemberSelected(user)
            return

        case .friendsSearch:
            break
        }

        if user.isFriend {
            showRemoveFriendAlert(for: user)
            return
        }

        if user.requestSent {
            showCancelRequestAlert(for: user)
            return
        }

        if user.requestReceived {
            return
        }

        Task { [weak self] in
            guard let self else { return }

            do {
                _ = try await viewModel.addToFriends(user)

                await MainActor.run {
                    self.updateUserState(
                        userId: user.id,
                        isFriend: false,
                        requestSent: true,
                        requestReceived: false
                    )
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(title: "Ошибка", message: error.localizedDescription)
                }
            }
        }
    }

}
