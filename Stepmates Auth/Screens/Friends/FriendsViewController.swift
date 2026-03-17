//
//  FriendsViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 02/02/2026.
//

import UIKit

protocol FriendsNavDelegate: AnyObject {
    func onSearchFriendsTapped()
}

final class FriendsViewController: UIViewController {
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
    
    private lazy var ratingLabel = UILabel.makeManrope(
        text: "Рейтинг дня:",
        style: Constants.manropeBold,
        size: 16,
        color: Constants.blue ?? .systemBlue
    )
    
    private let tableContainer = UIView()
    
    private lazy var tableView = UITableView.makeLeaderboardTable(
        dataSource: self,
        delegate: self
    )
    private let refreshControl = UIRefreshControl()
    
    private var items: [FriendLeaderboardItem] = []
    private let viewModel: ViewModel
    
    required init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }
    
}

extension FriendsViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        loadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }
}

private extension FriendsViewController {
    func setupViews() {
        view.backgroundColor = .white
        
        
        tableView.register(FriendLeaderboardCell.self, forCellReuseIdentifier: FriendLeaderboardCell.reuseId)
        tableView.rowHeight = 62
        
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
        
        tableContainer.translatesAutoresizingMaskIntoConstraints = false
        tableContainer.backgroundColor = .clear
        tableContainer.layer.cornerRadius = 24
        tableContainer.layer.borderWidth = 1
        tableContainer.layer.borderColor = (Constants.blue ?? .systemBlue).cgColor
        tableContainer.clipsToBounds = true
        
        tableContainer
            .addTo(view)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 26)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 16)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -16)
            .pinBottom(toAnchor: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        
        ratingLabel
            .addTo(tableContainer)
            .pinTop(toAnchor: tableContainer.topAnchor, constant: 15)
            .pinLeft(toAnchor: tableContainer.leftAnchor, constant: 16)
        
        tableView
            .addTo(tableContainer)
            .pinTop(toAnchor: ratingLabel.bottomAnchor, constant: 11)
            .pinLeft(toAnchor: tableContainer.leftAnchor, constant: 6)
            .pinRight(toAnchor: tableContainer.rightAnchor, constant: -6)
            .pinBottom(toAnchor: tableContainer.bottomAnchor, constant: -10)
    }
    
    func loadData(isRefreshing: Bool = false) {
        Task { [weak self] in
            guard let self else { return }
            
            let result = await self.viewModel.getLeaderboardItems()
            
            await MainActor.run {
                self.items = result
                self.tableView.reloadData()
                self.refreshControl.endRefreshing()
            }
        }
    }
}


extension FriendsViewController {
    
    @objc func onAddTapped() {
        navDelegate?.onSearchFriendsTapped()
    }
    
    @objc func onRefresh() {
        loadData(isRefreshing: true)
    }
}

extension FriendsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: FriendLeaderboardCell.reuseId,
            for: indexPath
        ) as? FriendLeaderboardCell else {
            return UITableViewCell()
        }
        
        cell.configure(with: items[indexPath.row])
        return cell
    }
}
