//
//  UITableExtensions.swift
//  Stepmates Auth
//
//  Created by Диана on 31/01/2026.
//

import UIKit

extension UITableView {
    static func makeUsersTable(dataSource: UITableViewDataSource? = nil, delegate: UITableViewDelegate? = nil) -> UITableView{
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = dataSource
        table.delegate = delegate
        table.separatorStyle = .singleLine
        table.keyboardDismissMode = .onDrag
        table.tableFooterView = UIView()
        return table
    }
    func registerDefaultCell(reuseId: String = "cell") {
            register(UITableViewCell.self, forCellReuseIdentifier: reuseId)
        }
    
    static func makeLeaderboardTable(dataSource: UITableViewDataSource? = nil, delegate: UITableViewDelegate? = nil) -> UITableView {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = dataSource
        table.delegate = delegate
        table.separatorStyle = .none
        table.backgroundColor = .clear
        table.showsVerticalScrollIndicator = false
        table.keyboardDismissMode = .onDrag
        table.tableFooterView = UIView()
        return table
    }
}
