//
//  GroupSettingsViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 09/05/2026.
//

import UIKit
import PhotosUI

protocol GroupSettingsNavDelegate: AnyObject {
    func onBackFromGroupSettings()
    func onAddMemberToExistingGroup(selectedUserIds: Set<Int>)
}

final class GroupSettingsViewController: UIViewController {

    weak var navDelegate: GroupSettingsNavDelegate?

    private let viewModel: ViewModel

    private var isEditingMode = false
    private var isSavingSettings = false
    private var selectedAvatar: UIImage?

    private lazy var titleLabel = UILabel.makeManrope(
        text: "Настройки группы",
        style: Constants.manropeExtraBold,
        size: 32,
        color: Constants.blue ?? .systemBlue
    )

    private lazy var editButton = UIButton.makeImageButton(
        imageName: "editGroupPageBtn",
        target: self,
        action: #selector(onEditTapped)
    )

    private lazy var closeEditButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = Constants.orange ?? .orange
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(onCloseEditTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    private let backgroundPanel = UIView()
    private let profileCard = UIView()

    private let avatarImageView = UIView.makeAvatarImageView(size: 88)

    private lazy var avatarAddButton = UIButton.makeImageButton(
        imageName: "createGroupBtn",
        target: self,
        action: #selector(onAvatarTapped)
    )

    private lazy var nameTextField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.textColor = .black
        field.font = UIFont(name: Constants.manropeExtraBold, size: 22)
            ?? .systemFont(ofSize: 22, weight: .bold)
        field.borderStyle = .none
        field.returnKeyType = .done
        field.isEnabled = false
        return field
    }()

    private lazy var statusTextField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.textColor = Constants.purple ?? .systemBlue
        field.font = UIFont(name: Constants.manropeMedium, size: 14)
            ?? .systemFont(ofSize: 14, weight: .medium)
        field.borderStyle = .none
        field.returnKeyType = .done
        field.isEnabled = false
        return field
    }()

    private lazy var goalTextField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.textColor = Constants.orange ?? .orange
        field.font = UIFont(name: Constants.manropeExtraBold, size: 16)
            ?? .systemFont(ofSize: 16, weight: .bold)
        field.backgroundColor = .white
        field.layer.cornerRadius = 22
        field.clipsToBounds = true
        field.keyboardType = .numberPad
        field.isEnabled = false

        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        field.leftView = padding
        field.leftViewMode = .always

        return field
    }()

    private lazy var membersTitleLabel = UILabel.makeManrope(
        text: "Участники:",
        style: Constants.manropeExtraBold,
        size: 17,
        color: Constants.blue ?? .systemBlue
    )

    private lazy var addMemberButton = UIButton.makeImageButton(
        imageName: "addMemberBtn",
        target: self,
        action: #selector(onAddMemberTapped)
    )

    private lazy var tableView: UITableView = {
        let table = UITableView.makeLeaderboardTable(dataSource: self, delegate: self)
        table.register(CreateGroupMemberCell.self, forCellReuseIdentifier: CreateGroupMemberCell.reuseId)
        table.rowHeight = 56
        table.isScrollEnabled = false
        return table
    }()

    private lazy var saveButton = UIButton.makePrimaryBigButton(
        title: "Сохранить",
        target: self,
        action: #selector(onSaveTapped)
    )

    private var tableHeightConstraint: NSLayoutConstraint?

    required init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }
}

// MARK: - Lifecycle
extension GroupSettingsViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        nameTextField.delegate = self
        statusTextField.delegate = self

        setupViews()
        render()
        applyCachedData()
        loadData()
    }
}

// MARK: - Setup
private extension GroupSettingsViewController {

    func setupViews() {
        view.backgroundColor = .white

        backgroundPanel.translatesAutoresizingMaskIntoConstraints = false
        backgroundPanel.backgroundColor = Constants.lightPurple
        backgroundPanel.layer.cornerRadius = 20
        backgroundPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        backgroundPanel.clipsToBounds = true

        titleLabel
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: Constants.titleTop)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 16)

        closeEditButton
            .addTo(view)
            .centerYOn(titleLabel)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -24)
            .setSize(width: 28, height: 28)

        editButton
            .addTo(view)
            .centerYOn(titleLabel)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -24)
            .setSize(width: 28, height: 28)

        backgroundPanel
            .addTo(view)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 22)
            .pinLeft(toAnchor: view.leftAnchor)
            .pinRight(toAnchor: view.rightAnchor)
            .pinBottom(toAnchor: view.bottomAnchor)

        profileCard.translatesAutoresizingMaskIntoConstraints = false
        profileCard.backgroundColor = .white
        profileCard.layer.cornerRadius = 20
        profileCard.clipsToBounds = true

        profileCard
            .addTo(view)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 30)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 10)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -10)
            .setHeight(116)

        avatarImageView.backgroundColor = Constants.lightPurple

        avatarImageView
            .addTo(profileCard)
            .centerYOn(profileCard)
            .pinLeft(toAnchor: profileCard.leftAnchor, constant: 22)
            .setSize(width: 88, height: 88)

        avatarAddButton
            .addTo(profileCard)
            .pinRight(toAnchor: avatarImageView.rightAnchor, constant: -2)
            .pinBottom(toAnchor: avatarImageView.bottomAnchor, constant: 0)
            .setSize(width: 28, height: 28)

        nameTextField
            .addTo(profileCard)
            .pinTop(toAnchor: profileCard.topAnchor, constant: 28)
            .pinLeft(toAnchor: avatarImageView.rightAnchor, constant: 16)
            .pinRight(toAnchor: profileCard.rightAnchor, constant: -16)
            .setHeight(30)

        statusTextField
            .addTo(profileCard)
            .pinTop(toAnchor: nameTextField.bottomAnchor, constant: 2)
            .pinLeft(toAnchor: avatarImageView.rightAnchor, constant: 16)
            .pinRight(toAnchor: profileCard.rightAnchor, constant: -16)
            .setHeight(24)

        goalTextField
            .addTo(view)
            .pinTop(toAnchor: profileCard.bottomAnchor, constant: 8)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 12)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -12)
            .setHeight(46)

        membersTitleLabel
            .addTo(view)
            .pinTop(toAnchor: goalTextField.bottomAnchor, constant: 34)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 32)

        addMemberButton
            .addTo(view)
            .centerYOn(membersTitleLabel)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -28)
            .setSize(width: 24, height: 24)

        tableView
            .addTo(view)
            .pinTop(toAnchor: membersTitleLabel.bottomAnchor, constant: 10)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor)

        tableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 0)
        tableHeightConstraint?.isActive = true

        saveButton
            .addTo(view)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 20)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -20)
            .pinBottom(toAnchor: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
            .setHeight(52)

        let avatarTap = UITapGestureRecognizer(target: self, action: #selector(onAvatarTapped))
        avatarImageView.addGestureRecognizer(avatarTap)

        let tap = UITapGestureRecognizer(target: self, action: #selector(onViewTapped))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        setEditingMode(false)
    }

    func applyCachedData() {
        guard viewModel.cachedDetailSnapshot() != nil else { return }
        render()
    }

    func loadData(force: Bool = false) {
        Task { [weak self] in
            guard let self else { return }

            await viewModel.loadDetail(force: force)

            await MainActor.run {
                self.render()
            }
        }
    }

    func render() {
        let detail = viewModel.detail

        nameTextField.text = detail?.name ?? viewModel.group.name
        statusTextField.text = detail?.status ?? viewModel.group.status

        let goal = detail?.goalSteps ?? viewModel.group.goalSteps
        goalTextField.text = "Цель: \(formatSteps(goal))"

        loadAvatar(detail?.avatarUrl ?? viewModel.group.avatarUrl)

        editButton.isHidden = !viewModel.isAdmin || isEditingMode
        closeEditButton.isHidden = !isEditingMode

        updateTableHeight()
        setEditingMode(isEditingMode)
    }

    func updateTableHeight() {
        tableHeightConstraint?.constant = CGFloat(viewModel.members.count) * 56
        tableView.reloadData()
    }

    func setEditingMode(_ editing: Bool) {
        isEditingMode = editing

        let canEdit = viewModel.isAdmin && editing

        nameTextField.isEnabled = canEdit && !isSavingSettings
        statusTextField.isEnabled = canEdit && !isSavingSettings
        goalTextField.isEnabled = canEdit && !isSavingSettings

        avatarAddButton.isHidden = !canEdit
        avatarAddButton.isEnabled = !isSavingSettings
        addMemberButton.isHidden = !canEdit
        addMemberButton.isEnabled = !isSavingSettings
        saveButton.isHidden = !canEdit
        saveButton.isEnabled = !isSavingSettings

        editButton.isHidden = !viewModel.isAdmin || isEditingMode
        editButton.isEnabled = !isSavingSettings
        closeEditButton.isHidden = !canEdit
        closeEditButton.isEnabled = !isSavingSettings

        tableView.reloadData()
    }

    func setSavingSettings(_ saving: Bool) {
        isSavingSettings = saving
        saveButton.setTitle(saving ? "Сохраняю..." : "Сохранить", for: .normal)
        saveButton.alpha = saving ? 0.72 : 1
        setEditingMode(isEditingMode)
    }

    func loadAvatar(_ avatarUrl: String?) {
        avatarImageView.image = nil
        avatarImageView.backgroundColor = Constants.lightPurple

        guard let avatarUrl, avatarUrl.isEmpty == false else { return }

        _ = AvatarLoader.shared.load(urlString: avatarUrl) { [weak self] image in
            guard let self else { return }

            if let image {
                self.avatarImageView.image = image
                self.avatarImageView.backgroundColor = .clear
            }
        }
    }

    func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    func rawGoalText() -> String {
        let text = goalTextField.text ?? ""
        return text
            .replacingOccurrences(of: "Цель:", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func friendlyInviteMessage(from error: Error) -> String {
        guard case let NetworkError.failedStatusCodeResponseData(_, data) = error else {
            return error.localizedDescription
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let detail = json["detail"] as? String {
                return detail
            }

            let messages = json.values.flatMap { value -> [String] in
                if let text = value as? String { return [text] }
                if let list = value as? [String] { return list }
                return []
            }

            if messages.contains(where: { $0.localizedCaseInsensitiveContains("приглашение") }) {
                return "Вы уже отправляли пользователю приглашение."
            }

            if let firstMessage = messages.first {
                return firstMessage
            }
        }

        let rawText = String(data: data, encoding: .utf8) ?? ""
        if rawText.localizedCaseInsensitiveContains("приглашение") {
            return "Вы уже отправляли пользователю приглашение."
        }

        return "Не удалось отправить приглашение. Попробуйте еще раз."
    }
}

// MARK: - Public
extension GroupSettingsViewController {

    func addMember(_ user: AccessUsers) {
        Task { [weak self] in
            guard let self else { return }

            do {
                try await self.viewModel.addMember(user)

                await MainActor.run {
                    self.updateTableHeight()
                    self.showOkAlert(
                        title: "Приглашение отправлено",
                        message: "\(user.username) будет добавлен(а) в группу, когда примет приглашение."
                    )
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(title: "Не удалось отправить", message: self.friendlyInviteMessage(from: error))
                }
            }
        }
    }
}

// MARK: - Actions
private extension GroupSettingsViewController {

    @objc func onEditTapped() {
        setEditingMode(true)
    }

    @objc func onCloseEditTapped() {
        selectedAvatar = nil
        view.endEditing(true)
        render()
        setEditingMode(false)
    }

    @objc func onAvatarTapped() {
        guard isEditingMode && viewModel.isAdmin else { return }

        let sheet = UIAlertController(title: "Фото группы", message: nil, preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Выбрать из галереи", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        })

        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))

        if let pop = sheet.popoverPresentationController {
            pop.sourceView = avatarImageView
            pop.sourceRect = avatarImageView.bounds
        }

        present(sheet, animated: true)
    }

    @objc func onAddMemberTapped() {
        guard isEditingMode && viewModel.isAdmin else { return }

        navDelegate?.onAddMemberToExistingGroup(
            selectedUserIds: viewModel.selectedMemberIds()
        )
    }

    @objc func onSaveTapped() {
        guard isSavingSettings == false else { return }
        setSavingSettings(true)

        Task { [weak self] in
            guard let self else { return }

            do {
                try await self.viewModel.saveChanges(
                    name: self.nameTextField.text ?? "",
                    status: self.statusTextField.text ?? "",
                    goal: self.rawGoalText(),
                    avatar: self.selectedAvatar
                )

                await MainActor.run {
                    self.setSavingSettings(false)
                    self.selectedAvatar = nil
                    self.render()
                    self.setEditingMode(false)
                }
            } catch {
                await MainActor.run {
                    self.setSavingSettings(false)
                    self.showOkAlert(title: "Ошибка", message: error.localizedDescription)
                }
            }
        }
    }

    @objc func onViewTapped() {
        view.endEditing(true)
    }

    func showDeleteAlert(for indexPath: IndexPath) {
        let member = viewModel.members[indexPath.row]

        let alert = UIAlertController(
            title: "Удалить участника",
            message: "Удалить \(member.username) из группы?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))

        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            self?.removeMember(at: indexPath)
        })

        present(alert, animated: true)
    }

    func removeMember(at indexPath: IndexPath) {
        Task { [weak self] in
            guard let self else { return }

            do {
                try await self.viewModel.removeMember(at: indexPath.row)

                await MainActor.run {
                    self.updateTableHeight()
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(title: "Ошибка", message: error.localizedDescription)
                }
            }
        }
    }

    func showMakeAdminAlert(for indexPath: IndexPath) {
        let member = viewModel.members[indexPath.row]

        let alert = UIAlertController(
            title: "Назначить админом",
            message: "Назначить \(member.username) админом группы?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))

        alert.addAction(UIAlertAction(title: "Назначить", style: .default) { [weak self] _ in
            self?.makeAdmin(at: indexPath)
        })

        present(alert, animated: true)
    }

    func makeAdmin(at indexPath: IndexPath) {
        Task { [weak self] in
            guard let self else { return }

            do {
                try await self.viewModel.makeAdmin(at: indexPath.row)

                await MainActor.run {
                    self.tableView.reloadRows(at: [indexPath], with: .automatic)
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(title: "Ошибка", message: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Table
extension GroupSettingsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.members.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: CreateGroupMemberCell.reuseId,
            for: indexPath
        ) as? CreateGroupMemberCell else {
            return UITableViewCell()
        }

        let member = viewModel.members[indexPath.row]

        cell.delegate = self
        cell.configure(
            with: member,
            isEditing: isEditingMode && viewModel.isAdmin,
            canEditThisMember: true
        )

        return cell
    }
}

// MARK: - Cell delegate
extension GroupSettingsViewController: CreateGroupMemberCellDelegate {

    func onDeleteMemberTapped(_ cell: CreateGroupMemberCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        showDeleteAlert(for: indexPath)
    }

    func onMakeAdminTapped(_ cell: CreateGroupMemberCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        showMakeAdminAlert(for: indexPath)
    }
}

// MARK: - Photo picker
extension GroupSettingsViewController: PHPickerViewControllerDelegate {

    func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)

        guard let item = results.first?.itemProvider else { return }
        guard item.canLoadObject(ofClass: UIImage.self) else { return }

        item.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let self, let image = obj as? UIImage else { return }

            DispatchQueue.main.async {
                let prepared = image.preparedForAvatar(maxSide: 512)
                self.selectedAvatar = prepared
                self.avatarImageView.image = prepared
                self.avatarImageView.backgroundColor = .clear
            }
        }
    }
}

// MARK: - UITextFieldDelegate
extension GroupSettingsViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
