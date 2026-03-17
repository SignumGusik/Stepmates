//
//  SearchFriendsViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 02/02/2026.
//

import UIKit

protocol SearchFriendsNavDelegate: AnyObject {
    func onCloseSearchTapped()
    func onUserSelected(_ user: AccessUsers)
}

final class SearchFriendsViewController: UIViewController {
    
    private lazy var titleLabel = UILabel.makeManrope(
        text: "Найди друзей",
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
    
    required init(viewModel: ViewModel) {
        self.viewModel = viewModel
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
    }
}

// MARK: - Setup
private extension SearchFriendsViewController {
    func setupViews() {
        view.backgroundColor = Constants.beige
        
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = 40
        
        titleLabel
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: Constants.titleTop)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 16)
        
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
        
        tableView
            .addTo(view)
            .pinTop(toAnchor: searchContainer.bottomAnchor, constant: 12)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 16)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -16)
            .pinBottom(toAnchor: view.safeAreaLayoutGuide.bottomAnchor, constant: 0)
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
            let result = await viewModel.getSearchFriends(query: text)
            await MainActor.run {
                self.filteredUsers = result
                self.tableView.reloadData()
            }
        }
    }
}

// MARK: - Actions
private extension SearchFriendsViewController {
    @objc func onCancelTapped() {
        searchTextField.text = ""
        filteredUsers = []
        tableView.reloadData()
        searchTextField.resignFirstResponder()
        setSearchActive(false, animated: true)
    }
    
    @objc func onClearTapped() {
        searchTextField.text = ""
        filteredUsers = []
        tableView.reloadData()
        clearButton.alpha = 0
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
        cell.configure(with: user, delegate: self)
        return cell
    }
}

extension SearchFriendsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let user = filteredUsers[indexPath.row]
        navDelegate?.onUserSelected(user)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - SearchFriendCellDelegate
// MARK: - SearchFriendCellDelegate
extension SearchFriendsViewController: SearchFriendCellDelegate {
    func onUserTapped(_ user: AccessUsers) {
        navDelegate?.onUserSelected(user)
    }
    
    func onActionTapped(_ user: AccessUsers) {
        if user.isFriend || user.requestSent || user.requestReceived {
            return
        }
        
        Task { [weak self] in
            guard let self else { return }
            
            do {
                _ = try await viewModel.addToFriends(user)
                
                if let index = filteredUsers.firstIndex(where: { $0.id == user.id }) {
                    filteredUsers[index].requestSent = true
                }
                
                await MainActor.run {
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
}
