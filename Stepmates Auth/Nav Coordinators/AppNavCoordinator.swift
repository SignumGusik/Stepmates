//
//  AppNavCoordinator.swift
//  Stepmates Auth
//
//  Created by Диана on 24/01/2026.
//

import UIKit

class AppNavCoordinator {
    let window: UIWindow
    var presenter: UINavigationController
    
    let tokenStorage = AccessTokenStorage()
    private let networkHandler = NetworkHandler()
    private lazy var friendsService = FriendsService(
        networkHandler: networkHandler,
        tokenStorage: tokenStorage
    )
    let didCompleteFirstLaunch = "com.signumina"
    private var lastResetEmail: String = ""
    
    init(window: UIWindow) {
        self.window = window
        self.presenter = UINavigationController()
        presenter.view.backgroundColor = .white
        setupNavigationBarAppearance()
        window.rootViewController = presenter
        window.makeKeyAndVisible()
    }
    
    func start() {
        let userDefaults = UserDefaults.standard
        if !userDefaults.bool(forKey: didCompleteFirstLaunch) {
            tokenStorage.delete()
            userDefaults.setValue(true, forKey: didCompleteFirstLaunch)
        }
        if tokenStorage.get() != nil {
            showHomeScreen()
        } else {
            showLoginScreen()
        }
        
        
    }
    
    func logout() {
        showLoginScreen()
        
    }
    
}

extension AppNavCoordinator {
    private func setupNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]

        let backImage = UIImage(named: "backArrow")?.withRenderingMode(.alwaysOriginal)
        appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)

        presenter.navigationBar.standardAppearance = appearance
        presenter.navigationBar.scrollEdgeAppearance = appearance
        presenter.navigationBar.compactAppearance = appearance
        presenter.navigationBar.tintColor = .clear
    }
}

// MARK: - Showing Screens
extension AppNavCoordinator {
    
    func showHomeScreen() {
        let viewModel = HomeViewController.ViewModel(
            username: "SignumGusik",
            networkHandler: networkHandler,
            tokenStorage: tokenStorage
        )
        let controller = HomeViewController(viewModel: viewModel)
        controller.navDelegate = self
        presenter.setViewControllers([controller], animated: true)
    }

    func shoeRegistrationScreen() {
        let viewModel = RegisterViewController.ViewModel(networkHandler: networkHandler)
        let controller = RegisterViewController(viewModel: viewModel)
        controller.navDelegate = self
        presenter.pushViewController(controller, animated: true)
    }

    func showLoginScreen() {
        let viewModel = LoginViewController.ViewModel(
            networkHandler: networkHandler,
            tokenStorage: tokenStorage
        )
        let controller = LoginViewController(viewModel: viewModel)
        controller.navDelegate = self
        presenter.setViewControllers([controller], animated: true)
    }

    func showSearchFriendsScreen() {
        let viewModel = SearchFriendsViewController.ViewModel(
            networkHandler: networkHandler,
            friendsService: friendsService,
            tokenStorage: tokenStorage
        )
        let controller = SearchFriendsViewController(viewModel: viewModel)
        controller.navDelegate = self
        presenter.pushViewController(controller, animated: true)
    }

    func showFriendsScreen() {
        let viewModel = FriendsViewController.ViewModel(
            networkHandler: networkHandler,
            friendsService: friendsService,
            tokenStorage: tokenStorage
        )
        let controller = FriendsViewController(viewModel: viewModel)
        controller.navDelegate = self
        presenter.pushViewController(controller, animated: true)
    }

    func showNotificationScreen() {
        let viewModel = NotificationsViewController.ViewModel(
            networkHandler: networkHandler,
            tokenStorage: tokenStorage
        )
        let controller = NotificationsViewController(viewModel: viewModel)
        presenter.pushViewController(controller, animated: true)
    }

    func showSelectedUserScreen(_ user: AccessUsers) {
        let viewModel = SelectedUserViewController.ViewModel(
            networkHandler: networkHandler,
            tokenStorage: tokenStorage,
            user: user
        )
        let controller = SelectedUserViewController(viewModel: viewModel)
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve

        presenter.present(controller, animated: true)
    }

    func showResetPasswordScreen() {
        let viewModel = ResetPasswordViewController.ViewModel(networkHandler: networkHandler)
        let controller = ResetPasswordViewController(viewModel: viewModel)
        controller.navDelegate = self
        presenter.pushViewController(controller, animated: true)
    }

    func showCodeVerifyScreen(email: String) {
        lastResetEmail = email
        let vm = CodeVerifyViewController.ViewModel(
            email: email,
            isRegistrationFlow: false,
            networkHandler: networkHandler,
            tokenStorage: tokenStorage
        )
        let vc = CodeVerifyViewController(viewModel: vm)
        vc.navDelegate = self
        presenter.pushViewController(vc, animated: true)
    }

    func showNewPasswordScreen(email: String, code: String) {
        let vm = NewPasswordViewController.ViewModel(
            email: email,
            code: code,
            networkHandler: networkHandler
        )
        let vc = NewPasswordViewController(viewModel: vm)
        vc.navDelegate = self
        presenter.pushViewController(vc, animated: true)
    }
    
    func showSettingsScreen(username: String) {
        let viewModel = SettingsViewController.ViewModel(username: username)
        let controller = SettingsViewController(viewModel: viewModel)
        controller.navDelegate = self
        presenter.pushViewController(controller, animated: true)
    }
    func showUsernameScreen() {
        let viewModel = UsernameViewController.ViewModel(
            networkHandler: networkHandler,
            tokenStorage: tokenStorage
        )
        let controller = UsernameViewController(viewModel: viewModel)
        controller.navDelegate = self
        presenter.pushViewController(controller, animated: true)
    }
    
}
extension AppNavCoordinator: HomeNavDelegate {
    func onLogoutTapped() {
        logout()
    }
    
    func onFriendsTapped() {
        showFriendsScreen()
    }
    
    func onNotificationsTapped() {
        showNotificationScreen()
    }
    
    func onSettingsTapped(username: String) {
        showSettingsScreen(username: username)
    }
}

extension AppNavCoordinator: LoginNavDelegate {
    func onRegisterTapped() {
        shoeRegistrationScreen()
        
    }
    func onLoginSuccessfull() {
        showHomeScreen()
    }
    func onForgotPassword() {
        showResetPasswordScreen()
    }
    
}

extension AppNavCoordinator: RegisterNavDelegate {
    func onRegistrationCodeSent(email: String) {
        let vm = CodeVerifyViewController.ViewModel(
            email: email,
            isRegistrationFlow: true,
            networkHandler: networkHandler,
            tokenStorage: tokenStorage
        )
        let vc = CodeVerifyViewController(viewModel: vm)
        vc.navDelegate = self
        presenter.pushViewController(vc, animated: true)
    }
    
    func onLoginTapped() {
        presenter.popViewController(animated: true)
    }
}

extension AppNavCoordinator: FriendsNavDelegate {
    
    func onSearchFriendsTapped() {
        showSearchFriendsScreen()
    }
}

extension AppNavCoordinator: SearchFriendsNavDelegate {
    func onCloseSearchTapped() {
        presenter.popViewController(animated: true)
    }
    
    func onUserSelected(_ user: AccessUsers) {
        showSelectedUserScreen(user)
    }
}

extension AppNavCoordinator: ResetPasswordNavDelegate {
    func onResetPasswordSubmitted(email: String) {
        showCodeVerifyScreen(email: email)
    }
}

extension AppNavCoordinator: CodeVerifyNavDelegate {
    func onBackFromCode() {
        presenter.popViewController(animated: true)
    }
    
    func onRegistrationVerified() {
        showUsernameScreen()
    }
    
    func onPasswordResetCodeVerified(code: String) {
        showNewPasswordScreen(email: lastResetEmail, code: code)
    }
}

extension AppNavCoordinator: NewPasswordNavDelegate {
    func onPasswordChangedSuccessfully() {
        showLoginScreen()
    }
    
    func onBackFromNewPassword() {
        
    }
    
}


extension AppNavCoordinator: SettingsNavDelegate {
    func onBackFromSettings() {
        presenter.popViewController(animated: true)
    }
    
    func onLogoutConfirmed() {
        tokenStorage.delete()
        showLoginScreen()
    }
    
    func onDeleteAccountConfirmed() {
        tokenStorage.delete()
        showLoginScreen()
    }
}
extension AppNavCoordinator: UsernameNavDelegate {
    func onUsernameSubmitted(username: String) {
        showHomeScreen()
    }
}


