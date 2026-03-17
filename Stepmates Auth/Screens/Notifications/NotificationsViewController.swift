//
//  NotificationsViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 06/02/2026.
//

import UIKit

class NotificationsViewController: UIViewController {
    private static let cellId = "cell"

    private lazy var tableView = UITableView.makeUsersTable(
            dataSource: self,
            delegate: nil
    )
    private let viewModel: ViewModel
    private var incoming: [AccessFriendRequests] = []
    required init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }
    
    
}

extension NotificationsViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.tintColor = .black
        setupViews()
        
    }
}

extension NotificationsViewController {
    func setupViews() {
        tableView.register(NotificationRequestCell.self, forCellReuseIdentifier: NotificationRequestCell.reuseId)
        tableView
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: 0)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 0)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: 0)
            .pinBottom(toAnchor: view.bottomAnchor, constant: 0)
        Task { [weak self] in
                    guard let self else { return }
                    do {
                        let items = try await self.viewModel.incomingFriendRequests()
                        await MainActor.run {
                            self.incoming = items
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

extension NotificationsViewController {
    private func loadIncoming() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let items = try await viewModel.incomingFriendRequests()
                await MainActor.run {
                    self.incoming = items
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    private func accept(req: AccessFriendRequests) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await viewModel.acceptRequest(req)
                await MainActor.run {
                    self.incoming.removeAll { $0.id == req.id }
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(title: "Error", message: self.serverMessage(from: error))
                }
            }
        }
    }

        	
    private func reject(req: AccessFriendRequests) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await viewModel.rejectRequest(req)
                await MainActor.run {
                    self.incoming.removeAll { $0.id == req.id }
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(title: "Error", message: self.serverMessage(from: error))
                }
            }
        }
    }

    private func serverMessage(from error: Error) -> String {
        if case let NetworkError.failedStatusCodeResponseData(_, data) = error,
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return error.localizedDescription
    }
}
extension NotificationsViewController : UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return incoming.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
                withIdentifier: NotificationRequestCell.reuseId,
                for: indexPath
            ) as? NotificationRequestCell else {
                return UITableViewCell()
            }
        let req = incoming[indexPath.row]
        cell.configure(title: req.fromUser.username, subtitle: req.fromUser.email)
        cell.onAcceptTapped = { [weak self] in self?.accept(req: req) }
        cell.onRejectTapped = { [weak self] in self?.reject(req: req) }

        return cell
    }
    
}
