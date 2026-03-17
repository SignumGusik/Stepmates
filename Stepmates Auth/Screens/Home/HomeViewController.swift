//
//  HomeViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 24/01/2026.
//

import UIKit
import Combine

protocol HomeNavDelegate: AnyObject {
    func onLogoutTapped()
    func onFriendsTapped()
    func onNotificationsTapped()
    func onSettingsTapped(username: String)
}

class HomeViewController: UIViewController {
    
    private let starsView = StarsBackgroundView()
    private lazy var infoText = UITextView.makeTextField()
    private lazy var fetchDataButton = UIButton.makeButton(title: "Fetch Secure Data", target: self, action: #selector(self.onFetchTapped))
    private lazy var resetButton = UIButton.makeButton(title: "Reset Text", target: self, action: #selector(self.onResetTextTapped))
    private lazy var logoutButton = UIButton.makeButton(title: "Logout", target: self, action: #selector(self.onLogoutTapped))
    private lazy var friendsButton = UIButton.makeHomeInfoButton(
        title: "Друзья",
        subtitle: "9 друзей",
        imageName: "friends",
        backgroundColor: Constants.purple ?? .systemBlue,
        target: self,
        action: #selector(onFriendsTapped)
    )
    private lazy var groupsButton = UIButton.makeHomeInfoButton(
        title: "Группы",
        subtitle: "3 группы",
        imageName: "groups",
        backgroundColor: Constants.blue ?? .systemBlue,
        target: self,
        action: #selector(onGroupsTapped)
    )
    
    private lazy var planetButton = UIButton.makeImageButton(
        imageName: "planet",
        target: self,
        action: #selector(onPlanetTapped)
    )
    
    
    private lazy var statsButtonsStack = UIStackView.makeHomeStatsButtonsStack(
        arrangedSubviews: [groupsButton, friendsButton]
    )
    private lazy var todayLabel = UILabel.makeManrope(text: "Сегодня:", style: Constants.manropeMedium, size: 16)
    private lazy var stepsLabel = UILabel.makeManrope(text: "9000 шагов", style: Constants.manropeBold, size: 40, color: Constants.blue ?? .systemBlue)
    private lazy var goalLabel = UILabel.makeManrope(text: "Цель: 10 000", style: Constants.manropeExtraBold, size: 20, color: Constants.orange ?? .orange)

    private let progressBar = GoalProgressView()
    private let statsCard = UIView()
    
    private var steps: CGFloat = 0
    private let goal: CGFloat = 10000
    
    private lazy var notificationsButton = UIButton.makeRoundIconButton(
        imageName: "notifications",
        target: self,
        action: #selector(onNotificationsTapped)
    )

    private lazy var settingsButton = UIButton.makeRoundIconButton(
        imageName: "settings",
        target: self,
        action: #selector(onSettingsTapped)
    )

    private lazy var topButtonsStack = UIStackView.makeHomeTopRightButtonsStack(
        arrangedSubviews: [notificationsButton, settingsButton]
    )
    
    private var concellables = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    
    weak var navDelegate: HomeNavDelegate?
    private let viewModel: ViewModel
    required init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }
    
    deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            HealthKitManager.shared.stopObservingSteps()
        }
    
}

// MARK: - Lifecycle
extension HomeViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backButtonDisplayMode = .minimal
        setupViews()
        setupNavBar()
        setupObservers()
        setupHealthKit()
        setupAppStateObservers()
    }
}

// MARK: - View Setup/Configuration
private extension HomeViewController {
    
    func setupViews() {
        title = "Home"
        
        starsView.translatesAutoresizingMaskIntoConstraints = false
        starsView.addTo(view)
                .pinTop(toAnchor: view.topAnchor, constant: 0)
                .pinLeft(toAnchor: view.leftAnchor, constant: 0)
                .pinRight(toAnchor: view.rightAnchor, constant: 0)
                .pinBottom(toAnchor: view.bottomAnchor, constant: 0)

        view.sendSubviewToBack(starsView)
        
        topButtonsStack
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: 12)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -16)

        notificationsButton.setSize(width: 50, height: 50)
        settingsButton.setSize(width: 50, height: 50)

        notificationsButton.setContentHuggingPriority(.required, for: .vertical)
        notificationsButton.setContentCompressionResistancePriority(.required, for: .vertical)

        settingsButton.setContentHuggingPriority(.required, for: .vertical)
        settingsButton.setContentCompressionResistancePriority(.required, for: .vertical)
    
        
        planetButton
            .addTo(view)
            .pinTop(toAnchor: settingsButton.bottomAnchor)
            .centerXOn(view)
            .setWidth(310)
            .setHeight(310)
        
        statsCard.translatesAutoresizingMaskIntoConstraints = false
        statsCard.backgroundColor = Constants.lightPurple
        statsCard.layer.cornerRadius = 20
        statsCard.clipsToBounds = true

        statsCard
            .addTo(view)
            .pinTop(toAnchor: planetButton.bottomAnchor, constant: 20)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: 10)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -10)
            .setHeight(280)
        
        todayLabel
            .addTo(statsCard)
            .pinTop(toAnchor: statsCard.topAnchor, constant: 16)
            .pinLeft(toAnchor: statsCard.leftAnchor, constant: 20)

        stepsLabel
            .addTo(statsCard)
            .pinTop(toAnchor: todayLabel.bottomAnchor, constant: 6)
            .pinLeft(toAnchor: statsCard.leftAnchor, constant: 18)

        goalLabel
            .addTo(statsCard)
            .pinTop(toAnchor: stepsLabel.bottomAnchor, constant: 6)
            .pinLeft(toAnchor: statsCard.leftAnchor, constant: 20)

        // прогресс бар
        progressBar
            .addTo(statsCard)
            .pinTop(toAnchor: goalLabel.bottomAnchor, constant: 10)
            .pinLeft(toAnchor: statsCard.leftAnchor, constant: 20)
            .pinRight(toAnchor: statsCard.rightAnchor, constant: -16)
            .setHeight(8)
        

        progressBar.setProgress(steps / goal, animated: false)
        
        statsButtonsStack
            .addTo(statsCard)
            .pinTop(toAnchor: progressBar.bottomAnchor, constant: 22)
            .pinLeft(toAnchor: statsCard.leftAnchor, constant: 10)
            .pinRight(toAnchor: statsCard.rightAnchor, constant: -10)
            .setHeight(90)
        
    }
    
    private func setupNavBar() {
        navigationItem.backButtonDisplayMode = .minimal
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        
        if let backImage = UIImage(named: "backArrow")?.withRenderingMode(.alwaysOriginal) {
            appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
        }
        
        appearance.backButtonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.clear
        ]
        appearance.backButtonAppearance.highlighted.titleTextAttributes = [
            .foregroundColor: UIColor.clear
        ]
        
        let navBar = navigationController?.navigationBar
        navBar?.isTranslucent = true
        navBar?.setBackgroundImage(UIImage(), for: .default)
        navBar?.shadowImage = UIImage()
        navBar?.backgroundColor = .clear
        
        navBar?.standardAppearance = appearance
        navBar?.scrollEdgeAppearance = appearance
        navBar?.compactAppearance = appearance
        navBar?.tintColor = .clear
    }
    
}
// MARK: -Observers
private extension HomeViewController {
    func setupObservers() {
        
        viewModel.$infoText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newText in
                self?.infoText.text = newText }.store(in: &concellables)
    }
    
    func setupAppStateObservers() {
        let observer = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadTodaySteps()
        }
        
        observers.append(observer)
    }
    
}

private extension HomeViewController {
    func setupHealthKit() {
        HealthKitManager.shared.requestAuthorization { [weak self] success in
            guard success else { return }
            
            self?.loadTodaySteps()
            
            HealthKitManager.shared.startObservingSteps { [weak self] in
                self?.loadTodaySteps()
            }
        }
    }
    
    func loadTodaySteps() {
        HealthKitManager.shared.fetchTodaySteps { [weak self] stepsValue in
            guard let self else { return }
            
            let stepsInt = Int(stepsValue)
            self.steps = CGFloat(stepsValue)
            self.stepsLabel.text = "\(stepsInt) шагов"
            self.progressBar.setProgress(min(CGFloat(stepsValue) / self.goal, 1), animated: true)
            
            Task {
                await self.viewModel.syncTodaySteps(stepsInt)
            }
        }
    }
}

// MARK: - Actions
private extension HomeViewController {
    @objc func onFetchTapped() {
        Task {
            do {
                try await viewModel.fetchSecureData()
                
            } catch {
                await MainActor.run {
                    [weak self] in
                    self?.showOkAlert(title:"Error", message: error.localizedDescription)
                }
            }
        }
        
    }
    @objc func onResetTextTapped() {
        viewModel.resetInfoText()
    }
    @objc func onLogoutTapped() {
        navDelegate?.onLogoutTapped()
    }
    @objc func onFriendsTapped() {
        navDelegate?.onFriendsTapped()
    }
    @objc func onNotificationsTapped() {
        navDelegate?.onNotificationsTapped()
    }
    @objc func onGroupsTapped() {
        print("groups tapped")
    }
    @objc private func onPlanetTapped() {
        print("")
    }
    @objc private func onSettingsTapped() {
        navDelegate?.onSettingsTapped(username: viewModel.username)
    }
}
