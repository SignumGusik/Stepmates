//
//  SelectedUserViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 02/02/2026.
//

import UIKit

final class SelectedUserViewController: UIViewController {
    
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    
    private let cardView = UIView()
    private let avatarView = UIView.makeAvatarCircle(size: 80)
    
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
    
    private lazy var usernameLabel = UILabel.makeManrope(
        text: viewModel.user.username,
        style: Constants.manropeMedium,
        size: 24,
        color: .black
    )
    
    private lazy var statusLabel = UILabel.makeManrope(
        text: "",
        style: Constants.manropeMedium,
        size: 12,
        color: Constants.orange ?? .orange
    )
    
    private lazy var addButton = UIButton.makeSearchResultActionButton(
        target: self,
        action: #selector(onAddTapped)
    )
    
    private let viewModel: ViewModel
    
    required init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }
}

// MARK: - Lifecycle
extension SelectedUserViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        updateAddButtonState()
    }
}

// MARK: - Setup
private extension SelectedUserViewController {
    func setupViews() {
        view.backgroundColor = .clear
        
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView
            .addTo(view)
            .pinTop(toAnchor: view.topAnchor, constant: 0)
            .pinLeft(toAnchor: view.leftAnchor, constant: 0)
            .pinRight(toAnchor: view.rightAnchor, constant: 0)
            .pinBottom(toAnchor: view.bottomAnchor, constant: 0)
        
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = Constants.beige
        cardView.layer.cornerRadius = 20
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = (Constants.blue ?? .systemBlue).cgColor
        cardView.clipsToBounds = true
        
        cardView
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: 230)
            .centerXOn(view)
            .setWidth(285)
            .setHeight(205)
        
        closeButton
            .addTo(cardView)
            .pinTop(toAnchor: cardView.topAnchor, constant: 10)
            .pinRight(toAnchor: cardView.rightAnchor, constant: -10)
            .setSize(width: 24, height: 24)
        
        profileLabel
            .addTo(cardView)
            .pinTop(toAnchor: cardView.topAnchor, constant: 16)
            .pinLeft(toAnchor: cardView.leftAnchor, constant: 12)
        
        avatarView
            .addTo(cardView)
            .pinTop(toAnchor: profileLabel.bottomAnchor, constant: 21)
            .pinLeft(toAnchor: cardView.leftAnchor, constant: 16)
            .setSize(width: 80, height: 80)
        
        avatarView.layer.cornerRadius = 40
        avatarView.backgroundColor = randomColor(for: viewModel.user.username)
        
        usernameLabel
            .addTo(cardView)
            .pinTop(toAnchor: avatarView.topAnchor, constant: 2)
            .pinLeft(toAnchor: avatarView.rightAnchor, constant: 14)
        
        
        addButton
            .addTo(cardView)
            .pinTop(toAnchor: usernameLabel.bottomAnchor, constant: 22)
            .pinLeft(toAnchor: avatarView.rightAnchor, constant: 14)
            .setWidth(88)
            .setHeight(24)
    }
    
    func randomColor(for username: String) -> UIColor {
        let colors: [UIColor] = [
            Constants.purple ?? .systemBlue,
            Constants.orange ?? .orange,
            Constants.blue ?? .blue,
            UIColor(hex: "#D8DDF8") ?? .systemGray4,
            UIColor(hex: "#000000") ?? .black,
            UIColor(hex: "#D7A692") ?? .brown
        ]
        
        let index = abs(username.hashValue) % colors.count
        return colors[index]
    }
    
    func updateAddButtonState() {
        let user = viewModel.user
        
        if user.isFriend {
            addButton.setTitle("Уже друг", for: .normal)
            addButton.backgroundColor = .clear
            addButton.setTitleColor(.black, for: .normal)
            addButton.isEnabled = false
            statusLabel.text = ""
            return
        }
        
        if user.requestSent {
            addButton.setTitle("Запрос", for: .normal)
            addButton.backgroundColor = Constants.orange ?? .orange
            addButton.setTitleColor(.white, for: .normal)
            addButton.isEnabled = false
            statusLabel.text = ""
            return
        }
        
        if user.requestReceived {
            addButton.setTitle("Запрос", for: .normal)
            addButton.backgroundColor = Constants.orange ?? .orange
            addButton.setTitleColor(.white, for: .normal)
            addButton.isEnabled = false
            statusLabel.text = ""
            return
        }
        
        addButton.setTitle("Добавить", for: .normal)
        addButton.backgroundColor = Constants.purple ?? .systemBlue
        addButton.setTitleColor(.white, for: .normal)
        addButton.isEnabled = true
        statusLabel.text = "Новичок"
    }
}

// MARK: - Actions
private extension SelectedUserViewController {
    @objc func onCloseTapped() {
        dismiss(animated: true)
    }
    
    @objc func onAddTapped() {
        Task { [weak self] in
            guard let self else { return }
            
            do {
                try await viewModel.addToFriends()
                await MainActor.run {
                    self.viewModel.user.requestSent = true
                    self.updateAddButtonState()
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
}
