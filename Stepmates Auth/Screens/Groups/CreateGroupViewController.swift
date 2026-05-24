//
//  CreateGroupViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 05/05/2026.
//

import UIKit
import PhotosUI

protocol CreateGroupNavDelegate: AnyObject {
    func onAddGroupMemberTapped(selectedUserIds: Set<Int>)
    func onGroupCreated()
}

final class CreateGroupViewController: UIViewController {

    weak var navDelegate: CreateGroupNavDelegate?

    private let viewModel: ViewModel
    private var selectedGroupAvatar: UIImage?

    private lazy var titleLabel = UILabel.makeManrope(
        text: "Создать группу",
        style: Constants.manropeExtraBold,
        size: 32,
        color: Constants.blue ?? .systemBlue
    )

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
        field.placeholder = "Название"
        field.textColor = .black
        field.font = UIFont(name: Constants.manropeExtraBold, size: 24)
            ?? .systemFont(ofSize: 24, weight: .bold)
        field.borderStyle = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done

        field.attributedPlaceholder = NSAttributedString(
            string: "Название",
            attributes: [
                .foregroundColor: UIColor.black,
                .font: UIFont(name: Constants.manropeExtraBold, size: 24)
                    ?? .systemFont(ofSize: 24, weight: .bold)
            ]
        )

        return field
    }()

    private lazy var goalButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Задайте общую цель группы", for: .normal)
        button.setTitleColor(Constants.orange ?? .orange, for: .normal)
        button.titleLabel?.font = UIFont(name: Constants.manropeExtraBold, size: 16)
            ?? .systemFont(ofSize: 16, weight: .bold)
        button.backgroundColor = .white
        button.layer.cornerRadius = 22
        button.clipsToBounds = true
        button.contentHorizontalAlignment = .left
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        button.addTarget(self, action: #selector(onGoalTapped), for: .touchUpInside)
        return button
    }()

    private lazy var membersTitleLabel = UILabel.makeManrope(
        text: "Добавьте участников",
        style: Constants.manropeExtraBold,
        size: 17,
        color: Constants.blue ?? .systemBlue
    )

    private lazy var addMemberButton = UIButton.makeImageButton(
        imageName: "addMemberBtn",
        target: self,
        action: #selector(onAddMemberTapped)
    )

    private lazy var createButton = UIButton.makePrimaryBigButton(
        title: "Создать группу",
        target: self,
        action: #selector(onCreateTapped)
    )

    private lazy var tableView: UITableView = {
        let table = UITableView.makeLeaderboardTable(dataSource: self, delegate: self)
        table.register(CreateGroupMemberCell.self, forCellReuseIdentifier: CreateGroupMemberCell.reuseId)
        table.rowHeight = 56
        table.isScrollEnabled = false
        return table
    }()

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
extension CreateGroupViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        nameTextField.delegate = self
        setupViews()
        updateTableHeight()
    }
}

// MARK: - Setup
private extension CreateGroupViewController {

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

        backgroundPanel
            .addTo(view)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 22)
            .pinLeft(toAnchor: view.leftAnchor, constant: 0)
            .pinRight(toAnchor: view.rightAnchor, constant: 0)
            .pinBottom(toAnchor: view.bottomAnchor, constant: 0)

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
        avatarImageView.image = UIImage(systemName: "photo")
        avatarImageView.tintColor = .white

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
            .centerYOn(profileCard)
            .pinLeft(toAnchor: avatarImageView.rightAnchor, constant: 16)
            .pinRight(toAnchor: profileCard.rightAnchor, constant: -16)
            .setHeight(44)

        goalButton
            .addTo(view)
            .pinTop(toAnchor: profileCard.bottomAnchor, constant: 8)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 12)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -12)
            .setHeight(46)

        membersTitleLabel
            .addTo(view)
            .pinTop(toAnchor: goalButton.bottomAnchor, constant: 34)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 32)

        addMemberButton
            .addTo(view)
            .centerYOn(membersTitleLabel)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -28)
            .setSize(width: 24, height: 24)

        tableView
            .addTo(view)
            .pinTop(toAnchor: membersTitleLabel.bottomAnchor, constant: 10)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 0)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: 0)

        tableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 0)
        tableHeightConstraint?.isActive = true

        createButton
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
    }

    func updateTableHeight() {
        tableHeightConstraint?.constant = CGFloat(viewModel.members.count) * 56
        tableView.reloadData()
    }
    
}

extension CreateGroupViewController {
    func addMember(_ user: AccessUsers) {
        viewModel.addMember(user)
        updateTableHeight()
    }
}

// MARK: - Actions
private extension CreateGroupViewController {

    @objc func onAvatarTapped() {
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

    @objc func onGoalTapped() {
        showOkAlert(title: "Скоро", message: "Цель группы добавим следующим шагом.")
    }

    @objc func onAddMemberTapped() {
        navDelegate?.onAddGroupMemberTapped(
            selectedUserIds: viewModel.selectedMemberIds()
        )
    }
    @objc func onViewTapped() {
        view.endEditing(true)
    }

    @objc func onCreateTapped() {
        Task { [weak self] in
            guard let self else { return }

            do {
                try await self.viewModel.createGroup(
                    name: self.nameTextField.text ?? "",
                    description: "",
                    avatar: self.selectedGroupAvatar
                )
                await MainActor.run {
                    self.navDelegate?.onGroupCreated()
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(
                        title: "Не получилось создать группу",
                        message: error.localizedDescription
                    )
                }
            }
        }
        
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
            self?.viewModel.removeMember(at: indexPath.row)
            self?.updateTableHeight()
        })

        present(alert, animated: true)
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
            self?.viewModel.makeAdmin(at: indexPath.row)
            self?.tableView.reloadRows(at: [indexPath], with: .automatic)
        })

        present(alert, animated: true)
    }
}

// MARK: - Table
extension CreateGroupViewController: UITableViewDataSource, UITableViewDelegate {

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

        cell.delegate = self
        cell.configure(with: viewModel.members[indexPath.row])
        return cell
    }
}

// MARK: - Member cell delegate
extension CreateGroupViewController: CreateGroupMemberCellDelegate {

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
extension CreateGroupViewController: PHPickerViewControllerDelegate {

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
                self.selectedGroupAvatar = prepared
                self.avatarImageView.image = prepared
                self.avatarImageView.backgroundColor = .clear
            }
        }
    }
}

// MARK: - UITextFieldDelegate
extension CreateGroupViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
