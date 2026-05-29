//
//  SettingsViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 17/03/2026.
//

import UIKit
import PhotosUI

protocol SettingsNavDelegate: AnyObject {
    func onBackFromSettings()
    func onLogoutConfirmed()
    func onDeleteAccountConfirmed()
    func onAddFriendFromSettingsTapped()
}

final class SettingsViewController: UIViewController {

    weak var navDelegate: SettingsNavDelegate?
    private let viewModel: ViewModel

    private lazy var backButton = UIButton.makeImageButton(
        imageName: "Arrow 18",
        target: self,
        action: #selector(onBackTapped)
    )

    private lazy var titleLabel = UILabel.makeManrope(
        text: "Настройки",
        style: Constants.manropeExtraBold,
        size: 32,
        color: Constants.blue ?? .systemBlue
    )
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private lazy var achievementsTitleLabel = UILabel.makeManrope(
        text: "Достижения",
        style: Constants.manropeExtraBold,
        size: 30,
        color: Constants.blue ?? .systemBlue
    )
    private lazy var streakSmallTitleLabel = UILabel.makeManrope(
        text: "Текущий стрейк",
        style: Constants.manropeExtraBold,
        size: 17,
        color: .white
    )

    private lazy var streakDaysLabel = UILabel.makeManrope(
        text: "0 дней",
        style: Constants.manropeExtraBold,
        size: 46,
        color: .white
    )

    private let achievementsContainer = UIView()
    private let achievementsScrollView = UIScrollView()
    private let achievementsContentStack = UIStackView()

    private let profileCard = UIView()
    private let avatarImageView = UIView.makeAvatarImageView(size: 80)

    private lazy var avatarEditButton = UIButton.makeAvatarEditBadge(
        target: self,
        action: #selector(onChangeAvatarTapped)
    )

    private lazy var usernameLabel = UILabel.makeManrope(
        text: viewModel.username,
        style: Constants.manropeExtraBold,
        size: 24,
        color: .black
    )

    private lazy var logoutButton = UIButton.makeSettingsActionButton(
        title: "Выйти из аккаунта",
        titleColor: Constants.purple ?? .systemBlue,
        target: self,
        action: #selector(onLogoutTapped)
    )

    private lazy var deleteButton = UIButton.makeSettingsActionButton(
        title: "Удалить аккаунт",
        titleColor: Constants.orange ?? .orange,
        target: self,
        action: #selector(onDeleteTapped)
    )
    
    private var isEditingMode = false
    private var isSavingProfile = false
    private var selectedAvatar: UIImage?

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
        button.addTarget(self, action: #selector(onCloseEditTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    private lazy var usernameTextField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.textColor = .black
        field.font = UIFont(name: Constants.manropeExtraBold, size: 24)
            ?? .systemFont(ofSize: 24, weight: .bold)
        field.borderStyle = .none
        field.returnKeyType = .done
        field.isEnabled = false
        return field
    }()

    private let emailIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(named: "email")?.withRenderingMode(.alwaysOriginal)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var emailLabel = UILabel.makeManrope(
        text: "",
        style: Constants.manropeMedium,
        size: 13,
        color: .gray
    )

    private let streakCard = UIView()

    private let streakIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(named: "streak_fire")?.withRenderingMode(.alwaysOriginal)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()


    private let friendsPreviewView = SettingsFriendsPreviewView()

    private let achievementsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        return stack
    }()

    private lazy var saveEditButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Сохранить", for: .normal)
        button.setTitleColor(Constants.orange ?? .orange, for: .normal)
        button.titleLabel?.font = UIFont(name: Constants.manropeExtraBold, size: 14)
            ?? .systemFont(ofSize: 14, weight: .bold)
        button.addTarget(self, action: #selector(onSaveTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()
    

    private let backgroundPanel = UIView()

    required init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }
}

// MARK: - Lifecycle
extension SettingsViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        usernameTextField.delegate = self
        setupViews()
        renderLocalAvatar()
        applyCachedProfileIfAvailable()
        loadProfile()
    }
}

// MARK: - UI
private extension SettingsViewController {

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

        editButton
            .addTo(view)
            .centerYOn(titleLabel)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -24)
            .setSize(width: 28, height: 28)

        closeEditButton
            .addTo(view)
            .centerYOn(titleLabel)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -24)
            .setSize(width: 28, height: 28)

        saveEditButton
            .addTo(view)
            .centerYOn(titleLabel)
            .pinRight(toAnchor: closeEditButton.leftAnchor, constant: -12)

        backgroundPanel
            .addTo(view)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 14)
            .pinLeft(toAnchor: view.leftAnchor)
            .pinRight(toAnchor: view.rightAnchor)
            .pinBottom(toAnchor: view.bottomAnchor)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true

        contentView.translatesAutoresizingMaskIntoConstraints = false

        scrollView
            .addTo(view)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 14)
            .pinLeft(toAnchor: view.leftAnchor)
            .pinRight(toAnchor: view.rightAnchor)
            .pinBottom(toAnchor: view.bottomAnchor)

        contentView.addTo(scrollView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leftAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leftAnchor),
            contentView.rightAnchor.constraint(equalTo: scrollView.contentLayoutGuide.rightAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        setupProfileCard()
        setupFriendsCard()
        setupStreakCard()
        setupAchievements()
        setupBottomButtons()
        setupGestures()

        setEditingMode(false)
    }
    
    func setupFriendsCard() {
        friendsPreviewView.onAddFriendTapped = { [weak self] in
            self?.navDelegate?.onAddFriendFromSettingsTapped()
        }

        friendsPreviewView
            .addTo(contentView)
            .pinTop(toAnchor: profileCard.bottomAnchor, constant: 24)
            .pinLeft(toAnchor: contentView.safeAreaLayoutGuide.leftAnchor, constant: 20)
            .pinRight(toAnchor: contentView.safeAreaLayoutGuide.rightAnchor, constant: -20)
            .setHeight(104)
    }
    
    func setupProfileCard() {
        profileCard.translatesAutoresizingMaskIntoConstraints = false
        profileCard.backgroundColor = .white
        profileCard.layer.cornerRadius = 20
        profileCard.clipsToBounds = true

        profileCard
            .addTo(contentView)
            .pinTop(toAnchor: contentView.topAnchor, constant: 41)
            .pinLeft(toAnchor: contentView.safeAreaLayoutGuide.leftAnchor, constant: 20)
            .pinRight(toAnchor: contentView.safeAreaLayoutGuide.rightAnchor, constant: -20)
            .setHeight(106)

        avatarImageView
            .addTo(profileCard)
            .centerYOn(profileCard)
            .pinLeft(toAnchor: profileCard.leftAnchor, constant: 28)
            .setSize(width: 80, height: 80)

        avatarEditButton
            .addTo(profileCard)
            .pinRight(toAnchor: avatarImageView.rightAnchor, constant: 2)
            .pinBottom(toAnchor: avatarImageView.bottomAnchor, constant: 2)

        usernameTextField.font = UIFont(name: Constants.manropeExtraBold, size: 24)
            ?? .systemFont(ofSize: 24, weight: .bold)

        usernameTextField
            .addTo(profileCard)
            .pinTop(toAnchor: profileCard.topAnchor, constant: 30)
            .pinLeft(toAnchor: avatarImageView.rightAnchor, constant: 32)
            .pinRight(toAnchor: profileCard.rightAnchor, constant: -16)
            .setHeight(30)

        emailIconView
            .addTo(profileCard)
            .pinTop(toAnchor: usernameTextField.bottomAnchor, constant: 5)
            .pinLeft(toAnchor: avatarImageView.rightAnchor, constant: 32)
            .setSize(width: 18, height: 18)

        emailLabel
            .addTo(profileCard)
            .centerYOn(emailIconView)
            .pinLeft(toAnchor: emailIconView.rightAnchor, constant: 8)
            .pinRight(toAnchor: profileCard.rightAnchor, constant: -16)
    }
    
    func setupStreakCard() {
        streakCard.translatesAutoresizingMaskIntoConstraints = false
        streakCard.backgroundColor = Constants.blue ?? UIColor(hex: "#2837B8")
        streakCard.layer.cornerRadius = 20
        streakCard.clipsToBounds = true

        streakCard
            .addTo(contentView)
            .pinTop(toAnchor: friendsPreviewView.bottomAnchor, constant: 26)
            .pinLeft(toAnchor: contentView.safeAreaLayoutGuide.leftAnchor, constant: 20)
            .pinRight(toAnchor: contentView.safeAreaLayoutGuide.rightAnchor, constant: -20)
            .setHeight(120)

        streakSmallTitleLabel
            .addTo(streakCard)
            .pinTop(toAnchor: streakCard.topAnchor, constant: 20)
            .pinLeft(toAnchor: streakCard.leftAnchor, constant: 26)

        streakDaysLabel
            .addTo(streakCard)
            .pinTop(toAnchor: streakSmallTitleLabel.bottomAnchor, constant: 2)
            .pinLeft(toAnchor: streakCard.leftAnchor, constant: 24)

        streakIconView
            .addTo(streakCard)
            .centerYOn(streakCard)
            .pinRight(toAnchor: streakCard.rightAnchor, constant: -28)
            .setSize(width: 76, height: 76)
    }
    
    func setupAchievements() {
        achievementsTitleLabel
            .addTo(contentView)
            .pinTop(toAnchor: streakCard.bottomAnchor, constant: 56)
            .pinLeft(toAnchor: contentView.safeAreaLayoutGuide.leftAnchor, constant: 20)

        achievementsContainer.translatesAutoresizingMaskIntoConstraints = false
        achievementsContainer.backgroundColor = .white
        achievementsContainer.layer.cornerRadius = 20
        achievementsContainer.clipsToBounds = true

        achievementsContainer
            .addTo(contentView)
            .pinTop(toAnchor: achievementsTitleLabel.bottomAnchor, constant: 14)
            .pinLeft(toAnchor: contentView.safeAreaLayoutGuide.leftAnchor, constant: 20)
            .pinRight(toAnchor: contentView.safeAreaLayoutGuide.rightAnchor, constant: -20)
            .setHeight(178)

        achievementsScrollView.translatesAutoresizingMaskIntoConstraints = false
        achievementsScrollView.showsHorizontalScrollIndicator = false
        achievementsScrollView.alwaysBounceHorizontal = true

        achievementsScrollView
            .addTo(achievementsContainer)
            .pinTop(toAnchor: achievementsContainer.topAnchor)
            .pinLeft(toAnchor: achievementsContainer.leftAnchor)
            .pinRight(toAnchor: achievementsContainer.rightAnchor)
            .pinBottom(toAnchor: achievementsContainer.bottomAnchor)

        achievementsContentStack.translatesAutoresizingMaskIntoConstraints = false
        achievementsContentStack.axis = .horizontal
        achievementsContentStack.alignment = .top
        achievementsContentStack.spacing = 24
        achievementsContentStack.distribution = .fill

        achievementsContentStack.addTo(achievementsScrollView)

        NSLayoutConstraint.activate([
            achievementsContentStack.topAnchor.constraint(equalTo: achievementsScrollView.contentLayoutGuide.topAnchor, constant: 24),
            achievementsContentStack.leftAnchor.constraint(equalTo: achievementsScrollView.contentLayoutGuide.leftAnchor, constant: 28),
            achievementsContentStack.rightAnchor.constraint(equalTo: achievementsScrollView.contentLayoutGuide.rightAnchor, constant: -28),
            achievementsContentStack.bottomAnchor.constraint(equalTo: achievementsScrollView.contentLayoutGuide.bottomAnchor, constant: -12),
            achievementsContentStack.heightAnchor.constraint(equalTo: achievementsScrollView.frameLayoutGuide.heightAnchor, constant: -36)
        ])
    }
    func setupBottomButtons() {
        logoutButton.addTo(contentView)
        deleteButton.addTo(contentView)

        logoutButton
            .pinTop(toAnchor: achievementsContainer.bottomAnchor, constant: 28)
            .pinLeft(toAnchor: contentView.safeAreaLayoutGuide.leftAnchor, constant: 20)
            .pinRight(toAnchor: contentView.safeAreaLayoutGuide.rightAnchor, constant: -20)
            .setHeight(58)

        deleteButton
            .pinTop(toAnchor: logoutButton.bottomAnchor, constant: 14)
            .pinLeft(toAnchor: contentView.safeAreaLayoutGuide.leftAnchor, constant: 20)
            .pinRight(toAnchor: contentView.safeAreaLayoutGuide.rightAnchor, constant: -20)
            .pinBottom(toAnchor: contentView.bottomAnchor, constant: -40)
            .setHeight(58)
    }
    
    func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(onChangeAvatarTapped))
        avatarImageView.addGestureRecognizer(tap)

        let hideKeyboardTap = UITapGestureRecognizer(target: self, action: #selector(onViewTapped))
        hideKeyboardTap.cancelsTouchesInView = false
        view.addGestureRecognizer(hideKeyboardTap)
    }

    func renderLocalAvatar() {
        if let img = viewModel.loadAvatarImage() {
            avatarImageView.image = img
            avatarImageView.backgroundColor = .clear
        } else {
            avatarImageView.image = nil
            avatarImageView.backgroundColor = viewModel.avatarColor
        }
    }
    func setEditingMode(_ editing: Bool) {
        isEditingMode = editing

        usernameTextField.isEnabled = editing && !isSavingProfile
        avatarEditButton.isHidden = !editing
        avatarEditButton.isEnabled = !isSavingProfile
        saveEditButton.isHidden = !editing
        saveEditButton.isEnabled = !isSavingProfile

        editButton.isHidden = editing
        editButton.isEnabled = !isSavingProfile
        closeEditButton.isHidden = !editing
        closeEditButton.isEnabled = !isSavingProfile
    }

    func setProfileSaving(_ saving: Bool) {
        isSavingProfile = saving
        saveEditButton.setTitle(saving ? "Сохраняю..." : "Сохранить", for: .normal)
        saveEditButton.alpha = saving ? 0.68 : 1
        usernameTextField.isEnabled = isEditingMode && !saving
        avatarEditButton.isEnabled = !saving
        closeEditButton.isEnabled = !saving
        editButton.isEnabled = !saving
    }
}

// MARK: - Server sync
private extension SettingsViewController {

    func syncAvatarFromServerIfNeeded() {
        Task { [weak self] in
            guard let self else { return }
            do {
                if let img = try await viewModel.syncAvatarIfNeeded() {
                    await MainActor.run {
                        self.avatarImageView.image = img
                        self.avatarImageView.backgroundColor = .clear
                    }
                }
            } catch {
                // можно оставить молча
                // либо показать: self.showOkAlert(...)
            }
        }
    }
}

// MARK: - Actions
private extension SettingsViewController {

    @objc func onBackTapped() {
        navDelegate?.onBackFromSettings()
    }

    @objc func onLogoutTapped() {
        let alert = UIAlertController(
            title: "Выйти из аккаунта",
            message: "Вы действительно хотите выйти из аккаунта?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Выйти", style: .destructive) { [weak self] _ in
            self?.navDelegate?.onLogoutConfirmed()
        })

        present(alert, animated: true)
    }

    @objc func onDeleteTapped() {
        let alert = UIAlertController(
            title: "Удалить аккаунт",
            message: "Вы действительно хотите удалить аккаунт?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            self?.navDelegate?.onDeleteAccountConfirmed()
        })

        present(alert, animated: true)
    }

    @objc func onChangeAvatarTapped() {
        guard isEditingMode else { return }
        let sheet = UIAlertController(title: "Фото профиля", message: nil, preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Выбрать из галереи", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        })

        sheet.addAction(UIAlertAction(title: "Сделать фото", style: .default) { [weak self] _ in
            self?.presentCamera()
        })

        // delete (disabled если нечего удалять)
        let hasAvatar = (viewModel.loadAvatarImage() != nil) || (viewModel.cachedAvatarUrl() != nil)
        let deleteAction = UIAlertAction(title: "Удалить фото", style: .destructive) { [weak self] _ in
            guard let self else { return }

            // UI сразу
            self.avatarImageView.image = nil
            self.avatarImageView.backgroundColor = self.viewModel.avatarColor

            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.viewModel.deleteAvatarRemoteAndLocal()
                } catch {
                    await MainActor.run {
                        self.showOkAlert(title: "Ошибка", message: self.serverMessage(from: error))
                        // если хочешь откатывать UI — можно снова renderLocalAvatar()
                    }
                }
            }
        }
        deleteAction.isEnabled = hasAvatar
        sheet.addAction(deleteAction)

        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))

        if let pop = sheet.popoverPresentationController {
            pop.sourceView = avatarImageView
            pop.sourceRect = avatarImageView.bounds
        }

        present(sheet, animated: true)
    }
    
    @objc func onEditTapped() {
        setEditingMode(true)
    }

    @objc func onCloseEditTapped() {
        selectedAvatar = nil
        view.endEditing(true)

        if let profile = viewModel.profile {
            render(profile)
        }

        setEditingMode(false)
    }

    @objc func onSaveTapped() {
        guard isSavingProfile == false else { return }
        setProfileSaving(true)

        Task { [weak self] in
            guard let self else { return }

            do {
                _ = try await self.viewModel.updateUsername(
                    self.usernameTextField.text ?? ""
                )

                if let selectedAvatar {
                    _ = try await self.viewModel.uploadAvatarToServer(selectedAvatar)
                }

                let freshProfile = try await self.viewModel.fetchMyProfile(force: true)

                await MainActor.run {
                    self.setProfileSaving(false)
                    self.selectedAvatar = nil
                    self.render(freshProfile)
                    self.setEditingMode(false)
                }
            } catch {
                await MainActor.run {
                    self.setProfileSaving(false)
                    self.showOkAlert(title: "Ошибка", message: self.serverMessage(from: error))
                }
            }
        }
    }
    @objc func onViewTapped() {
        view.endEditing(true)
    }
}

// MARK: - Pickers + apply
private extension SettingsViewController {

    func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showOkAlert(title: "Камера недоступна", message: "Запусти на реальном устройстве")
            return
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }

    func applyAvatar(_ image: UIImage) {
        let prepared = image.preparedForAvatar(maxSide: 512)

        selectedAvatar = prepared
        avatarImageView.image = prepared
        avatarImageView.backgroundColor = .clear
    }

    func serverMessage(from error: Error) -> String {
        if case let NetworkError.failedStatusCodeResponseData(_, data) = error,
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return error.localizedDescription
    }
    func applyCachedProfileIfAvailable() {
        guard let cachedProfile = viewModel.cachedProfileSnapshot() else { return }
        render(cachedProfile)
    }

    func loadProfile() {
        Task { [weak self] in
            guard let self else { return }

            do {
                let profile = try await viewModel.fetchMyProfile()

                await MainActor.run {
                    self.render(profile)
                }
            } catch {
                await MainActor.run {
                    if self.viewModel.cachedProfileSnapshot() == nil {
                        self.showOkAlert(title: "Ошибка", message: self.serverMessage(from: error))
                    }
                }
            }
        }
    }

    func render(_ profile: MyProfileDTO) {
        usernameTextField.text = profile.username
        emailLabel.text = profile.email
        streakDaysLabel.text = "\(profile.currentStreakDays) \(daysWord(profile.currentStreakDays))"

        friendsPreviewView.configure(
            count: profile.friendsCount,
            friends: profile.friendsPreview
        )

        renderAchievements(profile.achievements)

        if let avatarUrl = profile.avatarUrl, avatarUrl.isEmpty == false {
            _ = AvatarLoader.shared.load(urlString: avatarUrl) { [weak self] image in
                guard let self else { return }

                if let image {
                    self.avatarImageView.image = image
                    self.avatarImageView.backgroundColor = .clear
                    self.viewModel.saveAvatarImage(image)
                }
            }
        } else {
            renderLocalAvatar()
        }
    }

    func renderAchievements(_ achievements: [ProfileAchievementDTO]) {
        achievementsContentStack.arrangedSubviews.forEach {
            achievementsContentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        achievements.forEach { achievement in
            let view = AchievementProgressView()
            view.setSize(width: 82, height: 140)
            view.configure(with: achievement)
            achievementsContentStack.addArrangedSubview(view)
        }
    }

    func daysWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100

        if mod10 == 1 && mod100 != 11 {
            return "день"
        }

        if (2...4).contains(mod10) && !(12...14).contains(mod100) {
            return "дня"
        }

        return "дней"
    }
}

// MARK: - PHPicker delegate
extension SettingsViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)

        guard let item = results.first?.itemProvider else { return }
        guard item.canLoadObject(ofClass: UIImage.self) else { return }

        item.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let self, let img = obj as? UIImage else { return }
            DispatchQueue.main.async {
                self.applyAvatar(img)
            }
        }
    }
}

// MARK: - Camera picker delegate
extension SettingsViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)

        let img = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
        guard let img else { return }
        applyAvatar(img)
    }
}

extension SettingsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
