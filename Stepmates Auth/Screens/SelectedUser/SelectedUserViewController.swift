//
//  SelectedUserViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 02/02/2026.
//

import UIKit

final class SelectedUserViewController: UIViewController {

    private enum CardState {
        case loading
        case loaded
        case error
    }

    private let dimView = UIView()
    private let blurView = UIVisualEffectView(effect: nil)
    private let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)

    private let cardView = UIView()

    private var isClosing = false
    private var cardState: CardState = .loading
    private var didAnimateStatsIn = false

    private lazy var closeButton = UIButton.makeImageButton(
        imageName: "cancelBtn",
        target: self,
        action: #selector(onCloseTapped)
    )

    private lazy var profileLabel = UILabel.makeManrope(
        text: "Профиль:",
        style: Constants.manropeExtraBold,
        size: 16,
        color: Constants.blue ?? .systemBlue
    )

    private let avatarContainer = UIView()
    private let avatarImageView = UIImageView()

    private lazy var usernameLabel = UILabel.makeManrope(
        text: viewModel.user.username,
        style: Constants.manropeExtraBold,
        size: 24,
        color: .black
    )

    private lazy var addButton = UIButton.makeSearchResultActionButton(
        target: self,
        action: #selector(onAddTapped)
    )
    private lazy var ownProfileLabel = UILabel.makeManrope(
        text: "Я",
        style: Constants.manropeExtraBold,
        size: 16,
        color: .black
    )

    private let bottomStatsStack = UIStackView()
    private let leftStatsView = UIView()
    private let rightStatsView = UIView()

    private let leftAvatarsRow = UIView()
    private let rightAvatarsRow = UIView()

    private lazy var friendsCountLabel = UILabel.makeManrope(
        text: "",
        style: Constants.manropeExtraBold,
        size: 16,
        color: .black
    )

    private lazy var mutualCountLabel = UILabel.makeManrope(
        text: "",
        style: Constants.manropeExtraBold,
        size: 16,
        color: .black
    )

    private let viewModel: ViewModel

    private var mainAvatarTask: URLSessionDataTask?
    private var miniAvatarTasks: [URLSessionDataTask?] = []

    required init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }

    deinit {
        mainAvatarTask?.cancel()
        miniAvatarTasks.forEach { $0?.cancel() }
    }
}

// MARK: - Lifecycle
extension SelectedUserViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        prepareForPresentation()

        cardState = .loading
        renderUI()
        loadMainAvatarIfNeeded()
        animateIn()

        Task { [weak self] in
            guard let self else { return }

            do {
                try await self.viewModel.fetchUserCard()

                async let friendsImagesTask = self.preloadMiniAvatarImages(from: self.viewModel.friendsPreviewAvatarUrls)
                async let mutualImagesTask = self.preloadMiniAvatarImages(from: self.viewModel.mutualPreviewAvatarUrls)

                let friendsImages = await friendsImagesTask
                let mutualImages = await mutualImagesTask

                await MainActor.run {
                    self.cardState = .loaded
                    self.renderUI()
                    self.renderMiniAvatarRow(into: self.leftAvatarsRow, images: friendsImages)
                    self.renderMiniAvatarRow(into: self.rightAvatarsRow, images: mutualImages)
                    self.showStatsIfNeeded()
                }
            } catch {
                await MainActor.run {
                    self.cardState = .error
                    self.renderUI()
                    self.showStatsIfNeeded()
                }
            }
        }
    }
}

// MARK: - UI
private extension SelectedUserViewController {

    func setupViews() {
        view.backgroundColor = .clear

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView
            .addTo(view)
            .pinEdges(to: view)

        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.10)

        dimView
            .addTo(view)
            .pinEdges(to: view)

        let bgTap = UITapGestureRecognizer(target: self, action: #selector(onBackgroundTapped(_:)))
        bgTap.cancelsTouchesInView = false
        view.addGestureRecognizer(bgTap)

        cardView.applyRoundedBackground(color: .white, cornerRadius: 22)
        cardView.layer.borderWidth = 2
        cardView.layer.borderColor = (Constants.blue ?? .systemBlue).cgColor

        cardView
            .addTo(view)
            .centerXOn(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: 220)
            .setWidth(320)
            .setHeight(260)

        closeButton
            .addTo(cardView)
            .pinTop(toAnchor: cardView.topAnchor, constant: 14)
            .pinRight(toAnchor: cardView.rightAnchor, constant: -14)
            .setSize(width: 24, height: 24)

        profileLabel
            .addTo(cardView)
            .pinTop(toAnchor: cardView.topAnchor, constant: 16)
            .pinLeft(toAnchor: cardView.leftAnchor, constant: 16)

        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.layer.cornerRadius = 44
        avatarContainer.clipsToBounds = true
        avatarContainer.layer.borderWidth = 1
        avatarContainer.layer.borderColor = UIColor.black.withAlphaComponent(0.4).cgColor

        avatarContainer
            .addTo(cardView)
            .pinTop(toAnchor: profileLabel.bottomAnchor, constant: 14)
            .pinLeft(toAnchor: cardView.leftAnchor, constant: 16)
            .setSize(width: 88, height: 88)

        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true

        avatarImageView
            .addTo(avatarContainer)
            .pinEdges(to: avatarContainer)

        usernameLabel
            .addTo(cardView)
            .pinTop(toAnchor: avatarContainer.topAnchor, constant: 6)
            .pinLeft(toAnchor: avatarContainer.rightAnchor, constant: 14)
            .pinRight(toAnchor: closeButton.leftAnchor, constant: -10)

        addButton
            .addTo(cardView)
            .pinTop(toAnchor: usernameLabel.bottomAnchor, constant: 10)
            .pinLeft(toAnchor: avatarContainer.rightAnchor, constant: 14)
            .setWidth(120)
            .setHeight(30)

        bottomStatsStack.translatesAutoresizingMaskIntoConstraints = false
        bottomStatsStack.axis = .horizontal
        bottomStatsStack.alignment = .fill
        bottomStatsStack.distribution = .fillEqually
        bottomStatsStack.spacing = 12
        bottomStatsStack.alpha = 0
        bottomStatsStack.isHidden = true

        bottomStatsStack
            .addTo(cardView)
            .pinLeft(toAnchor: cardView.leftAnchor, constant: 16)
            .pinRight(toAnchor: cardView.rightAnchor, constant: -16)
            .pinBottom(toAnchor: cardView.bottomAnchor, constant: -18)
            .setHeight(80)

        bottomStatsStack.addArrangedSubview(leftStatsView)
        bottomStatsStack.addArrangedSubview(rightStatsView)

        setupStatsBlock(container: leftStatsView, avatarsRow: leftAvatarsRow, label: friendsCountLabel)
        setupStatsBlock(container: rightStatsView, avatarsRow: rightAvatarsRow, label: mutualCountLabel)
    }

    func setupStatsBlock(container: UIView, avatarsRow: UIView, label: UILabel) {
        container.translatesAutoresizingMaskIntoConstraints = false
        avatarsRow.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false

        avatarsRow
            .addTo(container)
            .pinTop(toAnchor: container.topAnchor, constant: 6)
            .pinLeft(toAnchor: container.leftAnchor, constant: 6)
            .setHeight(24)

        label
            .addTo(container)
            .pinTop(toAnchor: avatarsRow.bottomAnchor, constant: 8)
            .pinLeft(toAnchor: container.leftAnchor, constant: 6)
    }

    func renderUI() {
        usernameLabel.text = viewModel.user.username
        updateAddButtonState()

        if avatarImageView.image == nil {
            avatarContainer.backgroundColor = randomColor(for: viewModel.user.username)
        }

        switch cardState {
        case .loading:
            bottomStatsStack.isHidden = true
            bottomStatsStack.alpha = 0

        case .loaded:
            friendsCountLabel.text = "\(viewModel.friendsCount) друзей"
            mutualCountLabel.text = "\(viewModel.mutualFriendsCount) общих"

        case .error:
            friendsCountLabel.text = "Не удалось загрузить"
            mutualCountLabel.text = "Попробуйте снова"
            leftAvatarsRow.subviews.forEach { $0.removeFromSuperview() }
            rightAvatarsRow.subviews.forEach { $0.removeFromSuperview() }
        }
    }

    func showStatsIfNeeded() {
        guard didAnimateStatsIn == false else { return }

        didAnimateStatsIn = true
        bottomStatsStack.isHidden = false

        UIView.animate(withDuration: 0.20) {
            self.bottomStatsStack.alpha = 1
        }
    }

    func updateAddButtonState() {
        let user = viewModel.user

        addButton.isHidden = false

        if viewModel.isOwnProfile {
            addButton.setTitle("Я", for: .normal)
            addButton.backgroundColor = .clear
            addButton.setTitleColor(.black, for: .normal)
            addButton.isEnabled = false
            return
        }

        if user.isFriend || viewModel.source == .leaderboard {
            addButton.setTitle("Уже друг", for: .normal)
            addButton.backgroundColor = Constants.grey ?? UIColor.systemGray4
            addButton.setTitleColor(.black, for: .normal)
            addButton.isEnabled = true
            return
        }

        if user.requestSent {
            addButton.setTitle("Запрос", for: .normal)
            addButton.backgroundColor = Constants.orange ?? .orange
            addButton.setTitleColor(.white, for: .normal)
            addButton.isEnabled = true
            return
        }

        if user.requestReceived {
            addButton.setTitle("Запрос отправлен", for: .normal)
            addButton.backgroundColor = Constants.orange ?? .orange
            addButton.setTitleColor(.white, for: .normal)
            addButton.isEnabled = false
            return
        }

        addButton.setTitle("Добавить", for: .normal)
        addButton.backgroundColor = Constants.purple ?? .systemBlue
        addButton.setTitleColor(.white, for: .normal)
        addButton.isEnabled = true
    }
}

// MARK: - Avatar loading
private extension SelectedUserViewController {

    func loadMainAvatarIfNeeded() {
        mainAvatarTask?.cancel()

        guard let urlString = viewModel.user.avatarUrl, !urlString.isEmpty else {
            return
        }

        mainAvatarTask = AvatarLoader.shared.load(urlString: urlString) { [weak self] image in
            guard let self else { return }
            guard let image else { return }

            DispatchQueue.main.async {
                UIView.transition(with: self.avatarImageView, duration: 0.18, options: .transitionCrossDissolve) {
                    self.avatarImageView.image = image
                    self.avatarContainer.backgroundColor = .clear
                }
            }
        }
    }

    func preloadMiniAvatarImages(from urls: [String]) async -> [UIImage] {
        let limitedUrls = Array(urls.prefix(4))

        return await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, urlString) in limitedUrls.enumerated() {
                group.addTask {
                    let image = await self.loadImageAsync(urlString: urlString)
                    return (index, image)
                }
            }

            var ordered = Array<UIImage?>(repeating: nil, count: limitedUrls.count)

            for await (index, image) in group {
                ordered[index] = image
            }

            return ordered.compactMap { $0 }
        }
    }

    func loadImageAsync(urlString: String) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let task = AvatarLoader.shared.load(urlString: urlString) { image in
                continuation.resume(returning: image)
            }
            self.miniAvatarTasks.append(task)
        }
    }

    func renderMiniAvatarRow(into container: UIView, images: [UIImage]) {
        container.subviews.forEach { $0.removeFromSuperview() }

        let size: CGFloat = 22
        let overlap: CGFloat = 8

        for (i, image) in images.prefix(4).enumerated() {
            let iv = UIImageView()
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = size / 2
            iv.layer.borderWidth = 1
            iv.layer.borderColor = UIColor.black.withAlphaComponent(0.35).cgColor
            iv.image = image

            iv
                .addTo(container)
                .pinTop(toAnchor: container.topAnchor, constant: 0)
                .pinLeft(toAnchor: container.leftAnchor, constant: CGFloat(i) * (size - overlap))
                .setSize(width: size, height: size)
        }
    }

    func randomColor(for key: String) -> UIColor {
        let colors: [UIColor] = [
            Constants.purple ?? .systemBlue,
            Constants.orange ?? .orange,
            Constants.blue ?? .blue,
            UIColor(hex: "#D8DDF8") ?? .systemGray4,
            UIColor(hex: "#000000") ?? .black,
            UIColor(hex: "#D7A692") ?? .brown
        ]
        let index = abs(key.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Presentation animations
private extension SelectedUserViewController {

    func prepareForPresentation() {
        dimView.alpha = 0
        blurView.effect = nil
        cardView.alpha = 0
        cardView.transform = CGAffineTransform(translationX: 0, y: 18).scaledBy(x: 0.96, y: 0.96)
    }

    func animateIn() {
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
            self.dimView.alpha = 1
            self.blurView.effect = self.blurEffect
        }

        UIView.animate(
            withDuration: 0.45,
            delay: 0,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.8,
            options: [.curveEaseOut]
        ) {
            self.cardView.alpha = 1
            self.cardView.transform = .identity
        }
    }

    func animateOut(completion: (() -> Void)? = nil) {
        guard isClosing == false else { return }
        isClosing = true

        UIView.animate(withDuration: 0.20, delay: 0, options: [.curveEaseIn]) {
            self.dimView.alpha = 0
            self.blurView.effect = nil
        }

        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseIn]) {
            self.cardView.alpha = 0
            self.cardView.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        } completion: { _ in
            completion?()
        }
    }

    func close() {
        animateOut { [weak self] in
            self?.dismiss(animated: false)
        }
    }

    func showCancelRequestAlert() {
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
                    try await self.viewModel.cancelFriendRequest()
                    await MainActor.run {
                        self.updateAddButtonState()
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

    func showRemoveFriendAlert() {
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
                    try await self.viewModel.removeFromFriends()
                    await MainActor.run {
                        self.updateAddButtonState()
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
private extension SelectedUserViewController {

    @objc func onCloseTapped() {
        close()
    }

    @objc func onBackgroundTapped(_ gr: UITapGestureRecognizer) {
        let point = gr.location(in: view)
        if cardView.frame.contains(point) { return }
        close()
    }

    @objc func onAddTapped() {
        let user = viewModel.user

        if viewModel.isOwnProfile {
            return
        }

        if user.isFriend || viewModel.source == .leaderboard {
            showRemoveFriendAlert()
            return
        }

        if user.requestSent {
            showCancelRequestAlert()
            return
        }

        if user.requestReceived {
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await viewModel.addToFriends()
                await MainActor.run {
                    self.updateAddButtonState()
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(title: "Ошибка", message: error.localizedDescription)
                }
            }
        }
    }
}
