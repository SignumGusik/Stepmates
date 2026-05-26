//
//  GroupViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 05/05/2026.
//

import UIKit

protocol GroupNavDelegate: AnyObject {
    func onEditGroupTapped(group: GroupListItem)
    func onGroupLeft()
}

final class GroupViewController: UIViewController {

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

        var goalMultiplier: Int {
            switch self {
            case .today:
                return 1
            case .week:
                return 7
            case .month:
                let range = Calendar.current.range(of: .day, in: .month, for: Date())
                return range?.count ?? 30
            }
        }
    }

    weak var navDelegate: GroupNavDelegate?

    private let viewModel: ViewModel
    private var items: [GroupLeaderboardItem] = []
    private let refreshControl = UIRefreshControl()
    private var selectedPeriod: LeaderboardPeriod = .today

    private let avatarImageView = UIView.makeAvatarImageView(size: 80)

    private lazy var titleLabel = UILabel.makeManrope(
        text: viewModel.group.name,
        style: Constants.manropeExtraBold,
        size: 24,
        color: .black
    )

    private lazy var editButton = UIButton.makeImageButton(
        imageName: "EditGroupBtn",
        target: self,
        action: #selector(onEditTapped)
    )

    private lazy var membersTitleLabel = UILabel.makeManrope(
        text: "Всего участников:",
        style: Constants.manropeMedium,
        size: 16,
        color: .black
    )

    private lazy var membersValueLabel = UILabel.makeManrope(
        text: "\(viewModel.group.membersCount)",
        style: Constants.manropeExtraBold,
        size: 22,
        color: .black
    )

    private lazy var myPlaceTitleLabel = UILabel.makeManrope(
        text: "Вы:",
        style: Constants.manropeMedium,
        size: 16,
        color: .black
    )

    private lazy var myPlaceValueLabel = UILabel.makeManrope(
        text: viewModel.group.myPlace.map { "\($0)" } ?? "-",
        style: Constants.manropeExtraBold,
        size: 22,
        color: .black
    )
    

    private lazy var stepsProgressLabel: UILabel = {
        let label = UILabel.makeManrope(
            text: "",
            style: Constants.manropeExtraBold,
            size: 24,
            color: Constants.orange ?? .orange
        )
        label.textAlignment = .center
        return label
    }()

    private let dividerView = UIView()

    private lazy var ratingLabel = UILabel.makeManrope(
        text: "Рейтинг группы:",
        style: Constants.manropeExtraBold,
        size: 18,
        color: Constants.blue ?? .systemBlue
    )

    private let periodView = LeaderboardPeriodDropdownView()

    private lazy var tableView: UITableView = {
        let table = UITableView.makeLeaderboardTable(dataSource: self, delegate: self)
        table.register(GroupLeaderboardCell.self, forCellReuseIdentifier: GroupLeaderboardCell.reuseId)
        table.rowHeight = 60
        table.isScrollEnabled = true
        table.alwaysBounceVertical = true
        table.showsVerticalScrollIndicator = false
        return table
    }()
    

    private lazy var leaveButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Покинуть группу", for: .normal)
        button.setTitleColor(Constants.orange ?? .orange, for: .normal)
        button.titleLabel?.font = UIFont(name: Constants.manropeMedium, size: 16)
            ?? .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = Constants.beige ?? .systemGray6
        button.layer.cornerRadius = 24
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(onLeaveTapped), for: .touchUpInside)
        return button
    }()

    private let dropdownOverlay = UIControl()
    private let dropdownTable = UITableView(frame: .zero, style: .plain)
    private var dropdownHeightConstraint: NSLayoutConstraint?
    private var isDropdownOpen = false
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
extension GroupViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupDropdown()
        loadData()
    }
}

// MARK: - Setup
private extension GroupViewController {

    func setupViews() {
        view.backgroundColor = .white

        dividerView.translatesAutoresizingMaskIntoConstraints = false
        dividerView.backgroundColor = Constants.blue ?? .systemBlue

        avatarImageView.backgroundColor = Constants.lightPurple

        avatarImageView
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: 30)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 42)
            .setSize(width: 80, height: 80)

        editButton
            .addTo(view)
            .pinTop(toAnchor: avatarImageView.topAnchor, constant: 10)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -34)
            .setSize(width: 28, height: 28)

        titleLabel
            .addTo(view)
            .pinTop(toAnchor: avatarImageView.topAnchor, constant: 4)
            .pinLeft(toAnchor: avatarImageView.rightAnchor, constant: 22)
            .pinRight(toAnchor: editButton.leftAnchor, constant: -12)

        membersTitleLabel
            .addTo(view)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 12)
            .pinLeft(toAnchor: avatarImageView.rightAnchor, constant: 22)

        membersValueLabel
            .addTo(view)
            .pinTop(toAnchor: membersTitleLabel.bottomAnchor, constant: 2)
            .centerXOn(membersTitleLabel)

        myPlaceTitleLabel
            .addTo(view)
            .pinTop(toAnchor: membersTitleLabel.topAnchor, constant: 0)
            .pinRight(toAnchor: editButton.leftAnchor, constant: -36)

        myPlaceValueLabel
            .addTo(view)
            .pinTop(toAnchor: myPlaceTitleLabel.bottomAnchor, constant: 2)
            .centerXOn(myPlaceTitleLabel)

        stepsProgressLabel
            .addTo(view)
            .pinTop(toAnchor: avatarImageView.bottomAnchor, constant: 22)
            .centerXOn(view)

        dividerView
            .addTo(view)
            .pinTop(toAnchor: stepsProgressLabel.bottomAnchor, constant: 16)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 20)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -20)
            .setHeight(2)

        ratingLabel
            .addTo(view)
            .pinTop(toAnchor: dividerView.bottomAnchor, constant: 30)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 36)
        periodView.delegate = self
        periodView.setTitle(selectedPeriod.title)
        periodView.setExpanded(false, animated: false)

        periodView
            .addTo(view)
            .pinTop(toAnchor: ratingLabel.bottomAnchor, constant: 10)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 20)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -20)

        leaveButton
            .addTo(view)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 20)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -20)
            .pinBottom(toAnchor: view.safeAreaLayoutGuide.bottomAnchor, constant: -47)
            .setHeight(52)

        tableView
            .addTo(view)
            .pinTop(toAnchor: periodView.bottomAnchor, constant: 14)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 28)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -28)
            .pinBottom(toAnchor: leaveButton.topAnchor, constant: -16)

        loadGroupAvatar(viewModel.group.avatarUrl)
        
        refreshControl.addTarget(self, action: #selector(onRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        
    }

    func setupDropdown() {
        dropdownOverlay.translatesAutoresizingMaskIntoConstraints = false
        dropdownOverlay.backgroundColor = (Constants.grey ?? .systemGray5).withAlphaComponent(0.4)
        dropdownOverlay.alpha = 0
        dropdownOverlay.isHidden = true
        dropdownOverlay.addTarget(self, action: #selector(onOverlayTapped), for: .touchUpInside)

        dropdownOverlay
            .addTo(view)
            .pinTop(toAnchor: view.topAnchor)
            .pinLeft(toAnchor: view.leftAnchor)
            .pinRight(toAnchor: view.rightAnchor)
            .pinBottom(toAnchor: view.bottomAnchor)

        view.bringSubviewToFront(dropdownOverlay)

        dropdownTable.translatesAutoresizingMaskIntoConstraints = false
        dropdownTable.backgroundColor = .white
        dropdownTable.layer.cornerRadius = 18
        dropdownTable.clipsToBounds = true
        dropdownTable.rowHeight = dropdownRowHeight
        dropdownTable.isScrollEnabled = false
        dropdownTable.dataSource = self
        dropdownTable.delegate = self
        dropdownTable.register(UITableViewCell.self, forCellReuseIdentifier: "GroupPeriodCell")
        dropdownTable.layer.borderWidth = 2
        dropdownTable.layer.borderColor = (Constants.blue ?? .systemBlue).cgColor

        dropdownTable
            .addTo(dropdownOverlay)
            .pinTop(toAnchor: periodView.bottomAnchor, constant: 8)
            .pinLeft(toAnchor: periodView.leftAnchor)
            .pinRight(toAnchor: periodView.rightAnchor)

        dropdownHeightConstraint = dropdownTable.heightAnchor.constraint(equalToConstant: 0)
        dropdownHeightConstraint?.isActive = true
    }

    func loadData() {
        Task { [weak self] in
            guard let self else { return }

            async let detailTask = viewModel.getGroupDetail()
            async let leaderboardTask = viewModel.getLeaderboard(period: selectedPeriod)

            let detail = await detailTask
            let leaderboard = await leaderboardTask

            await MainActor.run {
                self.items = leaderboard
                self.tableView.reloadData()
                self.refreshControl.endRefreshing()

                if let detail {
                    self.membersValueLabel.text = "\(detail.members.count)"
                    if let myPlace = self.items.first(where: { $0.isCurrentUser })?.place {
                        self.myPlaceValueLabel.text = "\(myPlace)"
                    }
                }

                let total = self.viewModel.totalSteps(from: leaderboard)
                let goal = self.viewModel.goalSteps(detail: detail) * self.selectedPeriod.goalMultiplier
                self.stepsProgressLabel.attributedText = Self.makeProgressText(
                    total: total,
                    goal: goal
                )
            }
        }
    }

    func loadGroupAvatar(_ avatarUrl: String?) {
        avatarImageView.image = nil
        avatarImageView.backgroundColor = Constants.lightPurple

        guard
            let avatarUrl,
            avatarUrl.isEmpty == false
        else {
            return
        }

        _ = AvatarLoader.shared.load(urlString: avatarUrl) { [weak self] image in
            guard let self else { return }

            if let image {
                self.avatarImageView.image = image
                self.avatarImageView.backgroundColor = .clear
            }
        }
    }
}

// MARK: - Actions
private extension GroupViewController {

    @objc func onEditTapped() {
        navDelegate?.onEditGroupTapped(group: viewModel.group)
    }

    @objc func onLeaveTapped() {
        let alert = UIAlertController(
            title: "Покинуть группу",
            message: "Вы действительно хотите покинуть эту группу?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Покинуть", style: .destructive) { [weak self] _ in
            self?.leaveGroup()
        })

        present(alert, animated: true)
    }

    func leaveGroup() {
        Task { [weak self] in
            guard let self else { return }

            do {
                try await self.viewModel.leaveGroup()

                await MainActor.run {
                    self.navDelegate?.onGroupLeft()
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(title: "Ошибка", message: error.localizedDescription)
                }
            }
        }
    }

    @objc func onOverlayTapped() {
        hideDropdown()
    }
    @objc func onRefresh() {
        loadData()
    }
}

// MARK: - Dropdown
private extension GroupViewController {

    func showDropdown() {
        guard !isDropdownOpen else { return }

        isDropdownOpen = true
        dropdownOverlay.isHidden = false
        dropdownOverlay.alpha = 0
        dropdownHeightConstraint?.constant = dropdownMaxHeight

        periodView.setExpanded(true, animated: true)
        dropdownTable.reloadData()

        UIView.animate(withDuration: 0.24) {
            self.dropdownOverlay.alpha = 1
            self.view.layoutIfNeeded()
        }
    }

    func hideDropdown() {
        guard isDropdownOpen else { return }

        isDropdownOpen = false
        periodView.setExpanded(false, animated: true)
        dropdownHeightConstraint?.constant = 0

        UIView.animate(withDuration: 0.22) {
            self.dropdownOverlay.alpha = 0
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.dropdownOverlay.isHidden = true
        }
    }
}

// MARK: - Dropdown delegate
extension GroupViewController: LeaderboardPeriodDropdownViewDelegate {

    func onDropdownTapped() {
        isDropdownOpen ? hideDropdown() : showDropdown()
    }
}

// MARK: - Table
extension GroupViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView === dropdownTable {
            return LeaderboardPeriod.allCases.count
        }

        return items.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        if tableView === dropdownTable {
            let cell = tableView.dequeueReusableCell(withIdentifier: "GroupPeriodCell", for: indexPath)
            let period = LeaderboardPeriod.allCases[indexPath.row]

            var config = cell.defaultContentConfiguration()
            config.text = period.title
            config.textProperties.font = UIFont(name: Constants.manropeExtraBold, size: 16)
                ?? .systemFont(ofSize: 16, weight: .bold)
            config.textProperties.color = Constants.blue ?? .systemBlue

            cell.contentConfiguration = config
            cell.backgroundColor = .white
            cell.selectionStyle = .default

            return cell
        }

        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: GroupLeaderboardCell.reuseId,
            for: indexPath
        ) as? GroupLeaderboardCell else {
            return UITableViewCell()
        }

        cell.configure(with: items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView === dropdownTable {
            tableView.deselectRow(at: indexPath, animated: true)

            selectedPeriod = LeaderboardPeriod.allCases[indexPath.row]
            periodView.setTitle(selectedPeriod.title)

            hideDropdown()
            loadData()
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Helpers
private extension GroupViewController {

    static func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }
    
    static func makeProgressText(total: Int, goal: Int) -> NSAttributedString {
        let orange = Constants.orange ?? .orange
        let font = UIFont(name: Constants.manropeExtraBold, size: 24)
            ?? .systemFont(ofSize: 24, weight: .bold)

        let result = NSMutableAttributedString()

        result.append(NSAttributedString(
            string: formatSteps(total),
            attributes: [
                .font: font,
                .foregroundColor: orange
            ]
        ))

        result.append(NSAttributedString(
            string: " / ",
            attributes: [
                .font: font,
                .foregroundColor: orange.withAlphaComponent(0.45)
            ]
        ))

        result.append(NSAttributedString(
            string: formatSteps(goal),
            attributes: [
                .font: font,
                .foregroundColor: orange.withAlphaComponent(0.45)
            ]
        ))

        return result
    }
}
