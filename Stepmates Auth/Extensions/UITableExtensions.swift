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

    @discardableResult
    func applyPeriodDropdownStyle(
        rowHeight: CGFloat,
        borderColor: UIColor?
    ) -> Self {
        backgroundColor = .white
        layer.cornerRadius = 18
        clipsToBounds = true
        separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        self.rowHeight = rowHeight
        isScrollEnabled = false
        layer.borderWidth = 2
        layer.borderColor = (borderColor ?? .systemBlue).cgColor
        return self
    }
}
