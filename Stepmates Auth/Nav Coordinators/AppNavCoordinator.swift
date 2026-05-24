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
    private weak var currentCreateGroupController: CreateGroupViewController?
    private weak var currentGroupSettingsController: GroupSettingsViewController?
    private var shouldShowSplash = true
    
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

        if shouldShowSplash {
            shouldShowSplash = false
            showSplashScreen()
        } else {
            showInitialScreenAfterSplash()
        }
    }
    private func showInitialScreenAfterSplash() {
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
    func showSplashScreen() {
        let controller = SplashViewController()
        controller.navDelegate = self
        presenter.setViewControllers([controller], animated: false)
    }
    
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

    func showSelectedUserScreen(
        _ user: AccessUsers,
        source: SelectedUserProfileSource,
        isOwnProfile: Bool = false
    ) {
        let vm = SelectedUserViewController.ViewModel(
            user: user,
            source: source,
            isOwnProfile: isOwnProfile,
            networkHandler: networkHandler,
            friendsService: friendsService,
            tokenStorage: tokenStorage
        )
        let vc = SelectedUserViewController(viewModel: vm)

        presenter.present(vc, animated: true)
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
        let viewModel = SettingsViewController.ViewModel(
            username: username,
            networkHandler: networkHandler,
            tokenStorage: tokenStorage
        )
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
    func showMapScreen() {
        let controller = MapViewController()
        controller.navDelegate = self
        controller.onFriendTap = { [weak self] friend in
            self?.showFriendFromMap(friend)
        }
        presenter.pushViewController(controller, animated: true)
    }
    func showFriendFromMap(_ friend: FriendLiveLocation) {
        let user = AccessUsers(
            id: friend.userId,
            username: friend.username,
            email: "",
            firstName: "",
            lastName: "",
            isFriend: true,
            requestSent: false,
            requestReceived: false,
            avatarUrl: friend.avatarUrl
        )
        
        showSelectedUserScreen(
            user,
            source: .leaderboard,
            isOwnProfile: false
        )
    }
    func showGroupsScreen() {
        let viewModel = GroupsViewController.ViewModel(
            networkHandler: networkHandler,
            tokenStorage: tokenStorage
        )
        let controller = GroupsViewController(viewModel: viewModel)
        controller.navDelegate = self
        presenter.pushViewController(controller, animated: true)
    }
    
    func showCreateGroupScreen() {
        let viewModel = CreateGroupViewController.ViewModel(
            networkHandler: networkHandler,
            tokenStorage: tokenStorage
        )

        let controller = CreateGroupViewController(viewModel: viewModel)
        controller.navDelegate = self
        currentCreateGroupController = controller
        presenter.pushViewController(controller, animated: true)
    }
    func showGroupScreen(group: GroupListItem) {
        let viewModel = GroupViewController.ViewModel(
            group: group,
            networkHandler: networkHandler,
            tokenStorage: tokenStorage
        )

        let controller = GroupViewController(viewModel: viewModel)
        controller.navDelegate = self
        presenter.pushViewController(controller, animated: true)
    }
    func showGroupSettingsScreen(group: GroupListItem) {
        let viewModel = GroupSettingsViewController.ViewModel(
            group: group,
            networkHandler: networkHandler,
            tokenStorage: tokenStorage
        )

        let controller = GroupSettingsViewController(viewModel: viewModel)
        controller.navDelegate = self
        currentGroupSettingsController = controller
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
    func onMapTapped() {
        showMapScreen()
    }
    func onGroupsTapped() {
        showGroupsScreen()
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

    func onUserSelected(_ user: AccessUsers, source: SelectedUserProfileSource, isOwnProfile: Bool) {
        showSelectedUserScreen(user, source: source, isOwnProfile: isOwnProfile)
    }
}

extension AppNavCoordinator: SearchFriendsNavDelegate {
    func onCloseSearchTapped() {
        presenter.popViewController(animated: true)
    }

    func onUserSelected(_ user: AccessUsers, source: SelectedUserProfileSource) {
        showSelectedUserScreen(user, source: source, isOwnProfile: false)
    }

    func onGroupMemberSelected(_ user: AccessUsers) {
        if let settings = currentGroupSettingsController {
            settings.addMember(user)
            presenter.popViewController(animated: true)
            return
        }

        currentCreateGroupController?.addMember(user)
        presenter.popViewController(animated: true)
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
    func onAddFriendFromSettingsTapped() {
        showSearchFriendsScreen()
    }
}
extension AppNavCoordinator: UsernameNavDelegate {
    func onUsernameSubmitted(username: String) {
        showHomeScreen()
    }
}

extension AppNavCoordinator: GroupsNavDelegate {
    func onBackFromGroups() {
        presenter.popViewController(animated: true)
    }
    func onCreateGroupTapped() {
        showCreateGroupScreen()
    }
    func onGroupSelected(_ group: GroupListItem) {
        showGroupScreen(group: group)
    }
}

extension AppNavCoordinator: CreateGroupNavDelegate {

    func onAddGroupMemberTapped(selectedUserIds: Set<Int>) {
        let viewModel = SearchFriendsViewController.ViewModel(
            networkHandler: networkHandler,
            friendsService: friendsService,
            tokenStorage: tokenStorage
        )

        let controller = SearchFriendsViewController(
            viewModel: viewModel,
            mode: .groupMemberSearch(selectedUserIds: selectedUserIds)
        )

        controller.navDelegate = self
        presenter.pushViewController(controller, animated: true)
    }

    func onGroupCreated() {
        presenter.popViewController(animated: true)
    }
}

extension AppNavCoordinator: GroupNavDelegate {
    func onEditGroupTapped(group: GroupListItem) {
        showGroupSettingsScreen(group: group)
    }
    func onGroupLeft() {
        presenter.popViewController(animated: true)
    }
}

extension AppNavCoordinator: GroupSettingsNavDelegate {

    func onBackFromGroupSettings() {
        presenter.popViewController(animated: true)
    }

    func onAddMemberToExistingGroup(selectedUserIds: Set<Int>) {
        let viewModel = SearchFriendsViewController.ViewModel(
            networkHandler: networkHandler,
            friendsService: friendsService,
            tokenStorage: tokenStorage
        )

        let controller = SearchFriendsViewController(
            viewModel: viewModel,
            mode: .groupMemberSearch(selectedUserIds: selectedUserIds)
        )

        controller.navDelegate = self
        presenter.pushViewController(controller, animated: true)
    }
}

extension AppNavCoordinator: MapNavDelegate {
    func onFriendsRankingTapped() {
        showFriendsScreen()
    }

    func onGroupRankingTapped(groupId: Int) {
        showGroupsScreen()
    }
}

extension AppNavCoordinator: SplashNavDelegate {
    func onSplashFinished() {
        let nextController: UIViewController

        if tokenStorage.get() != nil {
            let viewModel = HomeViewController.ViewModel(
                username: "SignumGusik",
                networkHandler: networkHandler,
                tokenStorage: tokenStorage
            )
            let home = HomeViewController(viewModel: viewModel)
            home.navDelegate = self
            nextController = home
        } else {
            let viewModel = LoginViewController.ViewModel(
                networkHandler: networkHandler,
                tokenStorage: tokenStorage
            )
            let login = LoginViewController(viewModel: viewModel)
            login.navDelegate = self
            nextController = login
        }

        UIView.transition(
            with: window,
            duration: 0.45,
            options: [.transitionCrossDissolve]
        ) {
            self.presenter.setViewControllers([nextController], animated: false)
        }
    }
}
