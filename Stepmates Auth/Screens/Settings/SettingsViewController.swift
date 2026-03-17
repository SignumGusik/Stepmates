//
//  SettingsViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 17/03/2026.
//

import UIKit

protocol SettingsNavDelegate: AnyObject {
    func onBackFromSettings()
    func onLogoutConfirmed()
    func onDeleteAccountConfirmed()
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
    
    private let profileCard = UIView()
    private let avatarView = UIView.makeAvatarCircle(size: 80)
    
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
        setupViews()
    }
}

// MARK: - Setup
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
        
        backgroundPanel
            .addTo(view)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 14)
            .pinLeft(toAnchor: view.leftAnchor, constant: 0)
            .pinRight(toAnchor: view.rightAnchor, constant: 0)
            .pinBottom(toAnchor: view.bottomAnchor, constant: 0)
        
        profileCard.translatesAutoresizingMaskIntoConstraints = false
        profileCard.backgroundColor = .white
        profileCard.layer.cornerRadius = 20
        profileCard.clipsToBounds = true
        
        profileCard
            .addTo(view)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 22)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 10)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -10)
            .setHeight(120)
        
        avatarView
            .addTo(profileCard)
            .centerYOn(profileCard)
            .pinLeft(toAnchor: profileCard.leftAnchor, constant: 16)
            .setSize(width: 80, height: 80)
        
        avatarView.backgroundColor = viewModel.avatarColor
        
        usernameLabel
            .addTo(profileCard)
            .pinTop(toAnchor: profileCard.topAnchor, constant: 20)
            .pinLeft(toAnchor: avatarView.rightAnchor, constant: 14)
        
        
        logoutButton.addTo(view)
        deleteButton.addTo(view)
        logoutButton
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 10)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -10)
            .pinBottom(toAnchor: deleteButton.topAnchor, constant: -10)
            .setHeight(48)
        
        deleteButton
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 10)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -10)
            .pinBottom(toAnchor: view.safeAreaLayoutGuide.bottomAnchor, constant: -30)
            .setHeight(48)
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
}
