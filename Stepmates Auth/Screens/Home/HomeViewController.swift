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
    func onMapTapped()
    func onGroupsTapped()
}

class HomeViewController: UIViewController {

    private let starsView = StarsBackgroundView()
    private lazy var infoText = UITextView.makeTextField()
    private lazy var fetchDataButton = UIButton.makeButton(title: "Fetch Secure Data", target: self, action: #selector(self.onFetchTapped))
    private lazy var resetButton = UIButton.makeButton(title: "Reset Text", target: self, action: #selector(self.onResetTextTapped))
    private lazy var logoutButton = UIButton.makeButton(title: "Logout", target: self, action: #selector(self.onLogoutTapped))
    private lazy var friendsButton = UIButton.makeHomeInfoButton(
        title: "Друзья",
        subtitle: "загрузка",
        imageName: "friends",
        backgroundColor: Constants.purple ?? .systemBlue,
        target: self,
        action: #selector(onFriendsTapped)
    )
    private lazy var groupsButton = UIButton.makeHomeInfoButton(
        title: "Группы",
        subtitle: "загрузка",
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
    private lazy var stepsLabel = UILabel.makeManrope(text: "0 шагов", style: Constants.manropeBold, size: 40, color: Constants.blue ?? .systemBlue)
    private lazy var goalLabel = UILabel.makeManrope(text: "Цель: 10 000", style: Constants.manropeExtraBold, size: 20, color: Constants.orange ?? .orange)
    private lazy var streakBadgeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "0 дней"
        label.textAlignment = .center
        label.textColor = .white
        label.backgroundColor = Constants.orange ?? .orange
        label.font = UIFont(name: Constants.manropeExtraBold, size: 13)
            ?? .systemFont(ofSize: 13, weight: .heavy)
        label.layer.cornerRadius = 13
        label.clipsToBounds = true
        label.alpha = 0
        return label
    }()
    private lazy var goalCompletedBadgeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Цель выполнена"
        label.textAlignment = .center
        label.textColor = .white
        label.backgroundColor = Constants.orange ?? .orange
        label.font = UIFont(name: Constants.manropeExtraBold, size: 14)
            ?? .systemFont(ofSize: 14, weight: .heavy)
        label.layer.cornerRadius = 14
        label.clipsToBounds = true
        label.alpha = 0
        return label
    }()
    private let goalRowView = UIView()
    private lazy var editGoalButton = UIButton.makeImageButton(
        imageName: "editGroupPageBtn",
        target: self,
        action: #selector(onGoalEditTapped)
    )

    private let progressBar = GoalProgressView()
    private let statsCard = UIView()

    private var steps: CGFloat = 0
    private var dailyGoal = 10000
    private var goal: CGFloat {
        CGFloat(dailyGoal)
    }

    private let goalEditorView = HomeGoalEditorView()

    private lazy var notificationsButton = UIButton.makeRoundIconButton(
        imageName: "notifications",
        target: self,
        action: #selector(onNotificationsTapped)
    )
    private let notificationsDotView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = Constants.orange ?? .orange
        view.layer.cornerRadius = 5
        view.clipsToBounds = true
        view.isHidden = true
        return view
    }()

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
    private var goalRowHeightConstraint: NSLayoutConstraint?
    private var isStepCountingReady = false
    private var isHealthAccessActionEnabled = false
    private var isHomeVisible = false
    private var lastSyncedSteps: Int?
    private var lastSyncedStepsDateString: String?
    private var lastStepsSyncAt: Date?
    private var displayedSteps = 0
    private var displayedStepsDateString = HomeViewController.localDateString()
    private var stepCounterDisplayLink: CADisplayLink?
    private var stepCounterStartValue = 0
    private var stepCounterTargetValue = 0
    private var stepCounterStartedAt = Date()
    private let stepCounterDuration: TimeInterval = 0.34
    private var isLoadingHomeCounters = false
    private var lastHomeCountersLoadAt = Date.distantPast
    private let homeCountersReloadInterval: TimeInterval = 25

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
        stepCounterDisplayLink?.invalidate()
        StepCountProvider.shared.stop()
    }

}

// MARK: - Lifecycle
extension HomeViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backButtonDisplayMode = .minimal
        setupViews()
        setupGoalEditor()
        setupNavBar()
        setupObservers()
        setupAppStateObservers()
        applyCachedHomeCountersIfAvailable()
        resetStepsIfNeededForNewDay()
        loadHomeCounters()
        loadTodayStepsState()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isHomeVisible = true
        resetStepsIfNeededForNewDay()
        loadHomeCounters(force: true)
        loadTodayStepsState()
        setupStepCounting()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isHomeVisible = false
        StepCountProvider.shared.stop()
    }
}

// MARK: - View Setup/Configuration
private extension HomeViewController {

    func setupViews() {
        title = "Дом"

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

        notificationsDotView
            .addTo(notificationsButton)
            .pinTop(toAnchor: notificationsButton.topAnchor, constant: 8)
            .pinRight(toAnchor: notificationsButton.rightAnchor, constant: -8)
            .setSize(width: 10, height: 10)


        planetButton
            .addTo(view)
            .pinTop(toAnchor: settingsButton.bottomAnchor)
            .centerXOn(view)
            .setWidth(310)
            .setHeight(310)

        statsCard.translatesAutoresizingMaskIntoConstraints = false
        statsCard.applyRoundedBackground(
            color: Constants.lightPurple,
            cornerRadius: 20
        )

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

        streakBadgeLabel
            .addTo(statsCard)
            .pinRight(toAnchor: statsCard.rightAnchor, constant: -18)
            .centerYOn(todayLabel)
            .setSize(width: 92, height: 26)

        stepsLabel
            .addTo(statsCard)
            .pinTop(toAnchor: todayLabel.bottomAnchor, constant: 6)
            .pinLeft(toAnchor: statsCard.leftAnchor, constant: 18)
            .pinRight(toAnchor: statsCard.rightAnchor, constant: -18)
        stepsLabel.adjustsFontSizeToFitWidth = true
        stepsLabel.minimumScaleFactor = 0.72

        goalRowView
            .addTo(statsCard)
            .pinTop(toAnchor: stepsLabel.bottomAnchor, constant: 6)
            .pinLeft(toAnchor: statsCard.leftAnchor, constant: 20)
            .pinRight(toAnchor: statsCard.rightAnchor, constant: -20)
        goalRowHeightConstraint = goalRowView.heightAnchor.constraint(equalToConstant: 28)
        goalRowHeightConstraint?.isActive = true

        editGoalButton
            .addTo(goalRowView)
            .pinRight(toAnchor: goalRowView.rightAnchor, constant: 0)
            .centerYOn(goalRowView)
            .setSize(width: 22, height: 22)
        editGoalButton.accessibilityLabel = "Редактировать цель"

        goalLabel
            .addTo(goalRowView)
            .pinLeft(toAnchor: goalRowView.leftAnchor, constant: 0)
            .centerYOn(goalRowView)
            .pinRight(toAnchor: editGoalButton.leftAnchor, constant: -6)
        goalLabel.numberOfLines = 2
        goalLabel.isUserInteractionEnabled = true
        goalLabel.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(onStepsPermissionTapped))
        )

        stepsLabel.isUserInteractionEnabled = true
        stepsLabel.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(onStepsPermissionTapped))
        )

        // прогресс бар
        progressBar
            .addTo(statsCard)
            .pinTop(toAnchor: goalRowView.bottomAnchor, constant: 10)
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

        goalCompletedBadgeLabel
            .addTo(statsCard)
            .pinTop(toAnchor: progressBar.bottomAnchor, constant: 5)
            .centerXOn(statsCard)
            .setSize(width: 158, height: 28)
        statsCard.bringSubviewToFront(goalCompletedBadgeLabel)

    }

    func setupGoalEditor() {
        goalEditorView.attach(to: view)
        goalEditorView.onClose = { [weak self] in
            self?.hideGoalEditor()
        }
        goalEditorView.onTextChanged = { [weak self] in
            self?.validateGoalInput()
        }
        goalEditorView.onQuickGoal = { [weak self] _ in
            self?.validateGoalInput()
        }
        goalEditorView.onSave = { [weak self] in
            self?.saveGoalFromEditor()
        }
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

private extension HomeViewController {
    static var localStepsDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    static func localDateString(for date: Date = Date()) -> String {
        localStepsDateFormatter.string(from: date)
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
            guard let self, self.isHomeVisible else {
                return
            }

            self.resetStepsIfNeededForNewDay()
            self.loadHomeCounters()
            self.loadTodayStepsState()
            self.setupStepCounting()
        }

        observers.append(observer)

        let dayChangedObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isHomeVisible else {
                return
            }

            self.resetStepsIfNeededForNewDay()
            self.loadHomeCounters(force: true)
            self.loadTodayStepsState()
            self.setupStepCounting()
        }

        observers.append(dayChangedObserver)

        let stepSyncObserver = NotificationCenter.default.addObserver(
            forName: .stepSyncDidUpdateRecentDays,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isHomeVisible else {
                return
            }

            self.loadHomeCounters(force: true)
            self.loadTodayStepsState()
        }

        observers.append(stepSyncObserver)

        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isHomeVisible else {
                return
            }

            self.isStepCountingReady = false
            StepCountProvider.shared.stop()
        }

        observers.append(backgroundObserver)
    }

}

private extension HomeViewController {
    func setupStepCounting() {
        startStepCounting(showHelpIfUnavailable: false)
    }

    func startStepCounting(showHelpIfUnavailable: Bool) {
        resetStepsIfNeededForNewDay()
        isStepCountingReady = false
        showStepsDefaultState()

        StepCountProvider.shared.start { [weak self] snapshot in
            self?.applyStepSnapshot(snapshot)
        } onUnavailable: { [weak self] message in
            guard let self else { return }

            self.isStepCountingReady = false
            self.showStepsUnavailableState(message: "Нажмите, чтобы настроить шаги")

            if showHelpIfUnavailable {
                self.showStepsHelpAlert(message: message)
            }
        }
    }

    func loadTodaySteps() {
        guard isStepCountingReady else {
            return
        }

        StepCountProvider.shared.refresh()
    }

    func applyStepSnapshot(_ snapshot: StepCountSnapshot) {
        guard Calendar.current.isDateInToday(snapshot.date) else {
            return
        }

        resetStepsIfNeededForNewDay(referenceDate: snapshot.date)
        isStepCountingReady = true
        isHealthAccessActionEnabled = false

        applyStepsValue(snapshot.steps, animated: true, celebrate: true, date: snapshot.date)
        setGoalText(goalText(), isAction: false)

        syncStepsIfNeeded(snapshot.steps, date: snapshot.date)
    }

    func resetStepsIfNeededForNewDay(referenceDate: Date = Date()) {
        let currentDateString = Self.localDateString(for: referenceDate)
        guard displayedStepsDateString != currentDateString else {
            return
        }

        displayedStepsDateString = currentDateString
        lastSyncedSteps = nil
        lastSyncedStepsDateString = nil
        lastStepsSyncAt = nil

        stepCounterDisplayLink?.invalidate()
        stepCounterDisplayLink = nil
        displayedSteps = 0
        steps = 0
        stepsLabel.text = "\(formatSteps(0)) шагов"
        updateProgress(animated: false)
    }

    func isResponseDate(_ responseDate: String?, matching date: Date) -> Bool {
        responseDate == Self.localDateString(for: date)
    }

    func showStepsDefaultState() {
        isHealthAccessActionEnabled = false
        setGoalText(goalText(), isAction: false)
        updateProgress()
    }

    func showStepsUnavailableState(message: String) {
        applyStepsValue(0, animated: false, celebrate: false)
        isHealthAccessActionEnabled = true
        setGoalText(message, isAction: true)
        progressBar.setProgress(0, animated: true)
    }

    func syncStepsIfNeeded(_ steps: Int, date: Date = Date()) {
        let now = Date()
        let dateString = Self.localDateString(for: date)

        guard dateString == Self.localDateString() else {
            return
        }

        if let lastSyncedSteps,
           lastSyncedSteps == steps,
           lastSyncedStepsDateString == dateString {
            return
        }

        if let lastSyncedSteps,
           let lastStepsSyncAt,
           lastSyncedStepsDateString == dateString,
           now.timeIntervalSince(lastStepsSyncAt) < 60,
           abs(steps - lastSyncedSteps) < 25 {
            return
        }

        lastSyncedSteps = steps
        lastSyncedStepsDateString = dateString
        lastStepsSyncAt = now

        Task {
            let response = await viewModel.syncTodaySteps(steps, date: date)

            await MainActor.run {
                guard let goalSteps = response?.goalSteps,
                      self.isResponseDate(response?.date, matching: date)
                else {
                    return
                }

                self.applyDailyGoal(goalSteps, animated: true, celebrateIfCompleted: false)
            }
        }
    }

    func setGoalText(_ text: String, isAction: Bool) {
        let font = UIFont(name: Constants.manropeExtraBold, size: 20)
            ?? UIFont.systemFont(ofSize: 20, weight: .heavy)
        let color = Constants.orange ?? .orange
        let attributedText = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color
            ]
        )

        if isAction {
            attributedText.addAttribute(
                .underlineStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: NSRange(location: 0, length: attributedText.length)
            )
        }

        goalLabel.attributedText = attributedText
        editGoalButton.isHidden = isAction
        goalRowHeightConstraint?.constant = isAction ? 48 : 28
    }

    func goalText() -> String {
        "Цель: \(formatSteps(dailyGoal))"
    }

    func updateProgress(animated: Bool = true) {
        progressBar.setProgress(min(steps / goal, 1), animated: animated)
    }

    func applyDailyGoal(_ goal: Int, animated: Bool, celebrateIfCompleted: Bool = true) {
        let wasCompleted = Int(steps) >= dailyGoal
        dailyGoal = max(1000, min(100000, goal))
        guard isHealthAccessActionEnabled == false else {
            return
        }

        setGoalText(goalText(), isAction: false)
        updateProgress(animated: animated)

        if celebrateIfCompleted, !wasCompleted, Int(steps) >= dailyGoal {
            showGoalCompletedAnimation()
        }
    }

    func loadTodayStepsState() {
        let requestedDate = Date()
        resetStepsIfNeededForNewDay(referenceDate: requestedDate)

        Task { [weak self] in
            guard let self else { return }
            let state = await viewModel.loadTodayStepsState(date: requestedDate)

            await MainActor.run {
                self.resetStepsIfNeededForNewDay(referenceDate: requestedDate)

                if let goalSteps = state?.goalSteps {
                    self.applyDailyGoal(goalSteps, animated: false, celebrateIfCompleted: false)
                }

                guard self.isResponseDate(state?.date, matching: requestedDate) else {
                    return
                }

                if let todaySteps = state?.steps,
                   todaySteps > Int(self.steps) || self.isStepCountingReady == false {
                    self.applyStepsValue(todaySteps, animated: false, celebrate: false, date: requestedDate)
                }
            }
        }
    }

    func applyStepsValue(_ value: Int, animated: Bool, celebrate: Bool, date: Date = Date()) {
        let wasCompleted = Int(steps) >= dailyGoal
        let normalizedValue = max(0, value)

        displayedStepsDateString = Self.localDateString(for: date)
        steps = CGFloat(normalizedValue)
        setStepCounterValue(normalizedValue, animated: animated)
        updateProgress(animated: animated)

        if celebrate, !wasCompleted, normalizedValue >= dailyGoal {
            showGoalCompletedAnimation()
        }
    }

    func setStepCounterValue(_ value: Int, animated: Bool) {
        stepCounterDisplayLink?.invalidate()
        stepCounterDisplayLink = nil

        guard animated, displayedSteps != value else {
            displayedSteps = value
            stepsLabel.text = "\(formatSteps(value)) шагов"
            return
        }

        stepCounterStartValue = displayedSteps
        stepCounterTargetValue = value
        stepCounterStartedAt = Date()

        let displayLink = CADisplayLink(target: self, selector: #selector(onStepCounterFrame))
        displayLink.add(to: .main, forMode: .common)
        stepCounterDisplayLink = displayLink
    }

    @objc func onStepCounterFrame() {
        let elapsed = Date().timeIntervalSince(stepCounterStartedAt)
        let progress = min(elapsed / stepCounterDuration, 1)
        let eased = 1 - pow(1 - progress, 3)
        let delta = Double(stepCounterTargetValue - stepCounterStartValue)
        let value = stepCounterStartValue + Int((delta * eased).rounded())

        displayedSteps = value
        stepsLabel.text = "\(formatSteps(value)) шагов"

        if progress >= 1 {
            displayedSteps = stepCounterTargetValue
            stepsLabel.text = "\(formatSteps(stepCounterTargetValue)) шагов"
            stepCounterDisplayLink?.invalidate()
            stepCounterDisplayLink = nil
        }
    }

    func showGoalCompletedAnimation() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        progressBar.flashSuccess()

        goalCompletedBadgeLabel.layer.removeAllAnimations()
        goalCompletedBadgeLabel.alpha = 0
        goalCompletedBadgeLabel.transform = CGAffineTransform(translationX: 0, y: 10)
            .scaledBy(x: 0.96, y: 0.96)

        UIView.animate(
            withDuration: 0.24,
            delay: 0,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.6,
            options: [.curveEaseOut, .beginFromCurrentState]
        ) {
            self.goalCompletedBadgeLabel.alpha = 1
            self.goalCompletedBadgeLabel.transform = .identity
        } completion: { _ in
            UIView.animate(
                withDuration: 0.20,
                delay: 1.1,
                options: [.curveEaseIn, .beginFromCurrentState]
            ) {
                self.goalCompletedBadgeLabel.alpha = 0
                self.goalCompletedBadgeLabel.transform = CGAffineTransform(translationX: 0, y: -8)
            }
        }
    }

    func formatSteps(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    func showStepsHelpAlert(message: String) {
        let alert = UIAlertController(
            title: "Доступ к шагам",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Попробовать ещё раз", style: .default) { [weak self] _ in
            self?.startStepCounting(showHelpIfUnavailable: false)
        })

        alert.addAction(UIAlertAction(title: "Открыть настройки", style: .default) { [weak self] _ in
            self?.openAppSettings()
        })

        alert.addAction(UIAlertAction(title: "Понятно", style: .cancel))

        present(alert, animated: true)
    }

    func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsURL) else {
            return
        }

        UIApplication.shared.open(settingsURL)
    }

    func showGoalEditor() {
        goalEditorView.show(currentGoal: dailyGoal)
    }

    func hideGoalEditor() {
        goalEditorView.hide()
    }

    func parsedGoalInput() -> Int? {
        goalEditorView.parsedGoal()
    }

    func validateGoalInput() {
        goalEditorView.validateInput()
    }

    func applyCachedHomeCountersIfAvailable() {
        guard let counters = viewModel.cachedHomeCountersSnapshot() else { return }
        updateHomeCounters(counters)
    }

    func loadHomeCounters(force: Bool = false) {
        guard isLoadingHomeCounters == false else { return }

        let elapsed = Date().timeIntervalSince(lastHomeCountersLoadAt)
        guard force || elapsed >= homeCountersReloadInterval else { return }

        isLoadingHomeCounters = true
        Task { [weak self] in
            guard let self else { return }

            let counters = await viewModel.loadHomeCounters(force: force)

            await MainActor.run {
                self.isLoadingHomeCounters = false
                self.lastHomeCountersLoadAt = Date()
                self.updateHomeCounters(counters)
            }
        }
    }

    func updateHomeCounters(_ counters: HomeCounters) {
        if let dailyGoalSteps = counters.dailyGoalSteps {
            applyDailyGoal(dailyGoalSteps, animated: false, celebrateIfCompleted: false)
        }

        updateHomeInfoButton(
            friendsButton,
            title: "Друзья",
            subtitle: "\(counters.friendsCount) \(friendsWord(counters.friendsCount))"
        )

        updateHomeInfoButton(
            groupsButton,
            title: "Группы",
            subtitle: "\(counters.groupsCount) \(groupsWord(counters.groupsCount))"
        )

        notificationsDotView.isHidden = counters.notificationsCount == 0
        updateStreakBadge(days: counters.streakDays)
    }

    func updateStreakBadge(days: Int) {
        let safeDays = max(0, days)
        streakBadgeLabel.text = "\(safeDays) \(daysWord(safeDays))"
        streakBadgeLabel.alpha = safeDays > 0 ? 1 : 0.72

        UIView.animate(
            withDuration: 0.20,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState]
        ) {
            self.streakBadgeLabel.transform = safeDays > 0 ? .identity : CGAffineTransform(scaleX: 0.96, y: 0.96)
        }
    }

    func updateHomeInfoButton(_ button: UIButton, title: String, subtitle: String) {
        var config = button.configuration ?? UIButton.Configuration.plain()

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: Constants.manropeMedium, size: 18)
                ?? UIFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: UIColor.white
        ]

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: Constants.manropeMedium, size: 14)
                ?? UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.white
        ]

        config.attributedTitle = AttributedString(
            NSAttributedString(string: title, attributes: titleAttributes)
        )

        config.attributedSubtitle = AttributedString(
            NSAttributedString(string: subtitle, attributes: subtitleAttributes)
        )

        button.configuration = config
    }

    func friendsWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100

        if mod10 == 1 && mod100 != 11 {
            return "друг"
        }

        if (2...4).contains(mod10) && !(12...14).contains(mod100) {
            return "друга"
        }

        return "друзей"
    }

    func groupsWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100

        if mod10 == 1 && mod100 != 11 {
            return "группа"
        }

        if (2...4).contains(mod10) && !(12...14).contains(mod100) {
            return "группы"
        }

        return "групп"
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

    func animateTap(
        on targetView: UIView,
        scale: CGFloat = 0.94,
        completion: @escaping () -> Void
    ) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        UIView.animate(
            withDuration: 0.10,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState]
        ) {
            targetView.transform = CGAffineTransform(scaleX: scale, y: scale)
        } completion: { _ in
            UIView.animate(
                withDuration: 0.16,
                delay: 0,
                usingSpringWithDamping: 0.72,
                initialSpringVelocity: 0.7,
                options: [.curveEaseOut, .beginFromCurrentState]
            ) {
                targetView.transform = .identity
            } completion: { _ in
                completion()
            }
        }
    }

    func animatePlanetTransition(completion: @escaping () -> Void) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        UIView.animate(
            withDuration: 0.16,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState]
        ) {
            self.planetButton.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
            self.starsView.alpha = 0.68
        } completion: { _ in
            completion()
            UIView.animate(withDuration: 0.18, delay: 0.04, options: [.curveEaseOut]) {
                self.planetButton.transform = .identity
                self.starsView.alpha = 1
            }
        }
    }

    func animateNotificationsTransition(completion: @escaping () -> Void) {
        UIView.animate(
            withDuration: 0.10,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState]
        ) {
            self.notificationsButton.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            self.notificationsDotView.alpha = 0
        } completion: { _ in
            UIView.animate(
                withDuration: 0.16,
                delay: 0,
                usingSpringWithDamping: 0.74,
                initialSpringVelocity: 0.7,
                options: [.curveEaseOut, .beginFromCurrentState]
            ) {
                self.notificationsButton.transform = .identity
            } completion: { _ in
                completion()
                self.notificationsDotView.alpha = 1
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
        animateTap(on: friendsButton) { [weak self] in
            self?.navDelegate?.onFriendsTapped()
        }
    }
    @objc func onNotificationsTapped() {
        animateNotificationsTransition { [weak self] in
            self?.navDelegate?.onNotificationsTapped()
        }
    }
    @objc func onStepsPermissionTapped() {
        guard isHealthAccessActionEnabled else {
            return
        }

        startStepCounting(showHelpIfUnavailable: true)
    }
    @objc func onGoalEditTapped() {
        showGoalEditor()
    }
    func saveGoalFromEditor() {
        guard let goal = parsedGoalInput() else {
            validateGoalInput()
            return
        }

        goalEditorView.setSaving(true)

        let requestedDate = Date()
        Task { [weak self] in
            guard let self else { return }

            do {
                let response = try await viewModel.updateDailyGoal(goal, date: requestedDate)

                await MainActor.run {
                    self.applyDailyGoal(response.dailyGoalSteps, animated: true)

                    if self.isResponseDate(response.date, matching: requestedDate),
                       let todaySteps = response.todaySteps {
                        self.applyStepsValue(
                            todaySteps,
                            animated: true,
                            celebrate: response.isGoalCompleted == true,
                            date: requestedDate
                        )
                    }

                    self.hideGoalEditor()
                    self.loadHomeCounters(force: true)
                }
            } catch {
                await MainActor.run {
                    self.goalEditorView.showSaveError()
                }
            }
        }
    }
    @objc private func onGroupsTapped() {
        animateTap(on: groupsButton) { [weak self] in
            self?.navDelegate?.onGroupsTapped()
        }
    }
    @objc private func onPlanetTapped() {
        animatePlanetTransition { [weak self] in
            self?.navDelegate?.onMapTapped()
        }
    }
    @objc private func onSettingsTapped() {
        animateTap(on: settingsButton) { [weak self] in
            guard let self else { return }
            self.navDelegate?.onSettingsTapped(username: self.viewModel.username)
        }
    }
}
