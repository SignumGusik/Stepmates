//
//  MapViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 09/05/2026.
//

import UIKit
import YandexMapsMobile
import CoreLocation
import Combine

protocol MapNavDelegate: AnyObject {
    func onFriendsRankingTapped()
    func onGroupRankingTapped(groupId: Int)
}

final class MapViewController: UIViewController {

    var onFriendTap: ((FriendLiveLocation) -> Void)?
    weak var navDelegate: MapNavDelegate?
    private var mapView: YMKMapView!

    private let trackingManager = TrackingManager.shared

    private let mapTokenStorage = AccessTokenStorage()
    private lazy var mapService = MapService(
        networkHandler: NetworkHandler(tokenStorage: mapTokenStorage),
        tokenStorage: mapTokenStorage
    )

    private lazy var viewModel = MapViewModel(mapService: mapService)

    private var cancellables = Set<AnyCancellable>()

    private var didMoveToUserLocation = false
    private var myRoutePolylines: [YMKPolylineMapObject] = []
    private var myRouteEventPlacemarks: [YMKPlacemarkMapObject] = []
    private var pendingRouteSegments: [TrackSegment]?
    private var routeRedrawWorkItem: DispatchWorkItem?
    private var lastRouteRedrawAt = Date.distantPast
    private let routeRedrawInterval: TimeInterval = 1.2

    private var currentUserPlacemark: YMKPlacemarkMapObject?
    private var currentUserAccuracyCircle: YMKCircleMapObject?
    private var currentUserPulseCircle: YMKCircleMapObject?
    private var currentUserDisplayPoint: YMKPoint?
    private var currentUserAvatarImage: UIImage?
    private var pulseDisplayLink: CADisplayLink?
    private var pulseStartedAt = Date()
    private var friendsTimer: Timer?
    private var signalTimer: Timer?
    private var friendPlacemarks: [Int: YMKPlacemarkMapObject] = [:]
    private var currentFriendAvatarUrls: [Int: String] = [:]
    private var friendTapListeners: [Int: MapFriendTapListener] = [:]
    private var friendRoutePolylines: [Int: [YMKPolylineMapObject]] = [:]

    private let scopeChipsView = MapScopeChipsView()
    private var scopeChipsBottomConstraint: NSLayoutConstraint?
    private let stepsCardView = MapStepsCardView()
    private var isStepProviderActive = false

    private var isMapScreenActive = false
    private var isFollowModeEnabled = true
    private var followedFriendId: Int?
    private var currentSignalQuality: TrackQuality = .poor
    private var lastLocationUpdateAt: Date?
    private let signalLostAfter: TimeInterval = 28
    private let maximumAccuracyCircleRadius: CLLocationAccuracy = 220

    private let signalBadgeView = MapSignalBadgeView()
    private let centerOnMeButton = UIButton(type: .system)
    private let sharingToggleButton = UIButton(type: .system)
    private var isSharingLocation = true
    private let mapDimControl = UIControl()
    private let emptyRoutesView = MapEmptyRoutesView()
    private let friendCardView = MapFriendCardView()
    private var selectedFriend: FriendLiveLocation?

    private var placemarkAnimations: [Int: CADisplayLink] = [:]
    private var placemarkAnimationStarts: [Int: Date] = [:]
    private var placemarkAnimationFromPoints: [Int: YMKPoint] = [:]
    private var placemarkAnimationToPoints: [Int: YMKPoint] = [:]
    private var lastFollowCameraPoint: YMKPoint?
    private var lastFollowCameraMoveAt: Date?
    private let followCameraMinInterval: TimeInterval = 1.0
    private let followCameraMinDistance: CLLocationDistance = 8


    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupMap()

        trackingManager.configure(mapService: mapService)
        trackingManager.start()

        setupScopeChips()
        setupStepsCard()
        setupSignalBadge()
        setupCenterOnMeButton()
        setupSharingToggleButton()
        setupEmptyRoutesView()
        setupFriendCard()
        bindViewModel()

        loadCurrentUserAvatar()
        loadMyTrack()

        Task {
            await viewModel.loadInitialData()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        isMapScreenActive = true
        trackingManager.addObserver(self)
        startFriendsPolling()
        startSignalPolling()
        startLocalStepsUpdates()

        Task {
            await viewModel.reloadScopeData(includeRanking: false)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        isMapScreenActive = false
        trackingManager.removeObserver(self)
        stopFriendsPolling()
        stopSignalPolling()
        stopLocalStepsUpdates()
        stopPulse()
        routeRedrawWorkItem?.cancel()
        routeRedrawWorkItem = nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        mapView.frame = view.bounds
    }
}

// MARK: - Setup

private extension MapViewController {

    func setupView() {
        applyStepmatesBaseScreen()
        title = "Карта"
    }

    func setupMap() {
        mapView = YMKMapView(frame: view.bounds)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)
    }
    func setupCenterOnMeButton() {
        centerOnMeButton.translatesAutoresizingMaskIntoConstraints = false

        let image = UIImage(systemName: "location.fill")
        centerOnMeButton.setImage(image, for: .normal)
        centerOnMeButton.applyFloatingButtonStyle(
            cornerRadius: 24,
            tintColor: Constants.purple ?? .systemBlue,
            shadowOpacity: 0.14
        )

        centerOnMeButton.addTarget(
            self,
            action: #selector(onCenterOnMeTapped),
            for: .touchUpInside
        )

        centerOnMeButton.addTo(view)

        NSLayoutConstraint.activate([
            centerOnMeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            centerOnMeButton.bottomAnchor.constraint(equalTo: scopeChipsView.topAnchor, constant: -18),
            centerOnMeButton.widthAnchor.constraint(equalToConstant: 48),
            centerOnMeButton.heightAnchor.constraint(equalToConstant: 48)
        ])

        applyFollowModeState()
    }
    func setupSharingToggleButton() {
        sharingToggleButton.translatesAutoresizingMaskIntoConstraints = false
        sharingToggleButton.applyFloatingButtonStyle(
            cornerRadius: 22,
            tintColor: Constants.purple ?? .systemBlue,
            shadowOpacity: 0.12
        )
        sharingToggleButton.applyTitleStyle(
            fontName: Constants.manropeBold,
            size: 13,
            fallbackWeight: .bold,
            color: Constants.purple ?? .systemBlue
        )

        sharingToggleButton.addTarget(
            self,
            action: #selector(onSharingToggleTapped),
            for: .touchUpInside
        )

        sharingToggleButton.addTo(view)

        NSLayoutConstraint.activate([
            sharingToggleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            sharingToggleButton.bottomAnchor.constraint(equalTo: centerOnMeButton.topAnchor, constant: -12),
            sharingToggleButton.widthAnchor.constraint(equalToConstant: 104),
            sharingToggleButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        applySharingToggleState()
    }

    func applySharingToggleState() {
        let title = isSharingLocation ? "я видим" : "я скрыт"
        let icon = isSharingLocation ? "eye.fill" : "eye.slash.fill"

        sharingToggleButton.setTitle("  \(title)", for: .normal)
        sharingToggleButton.setImage(UIImage(systemName: icon), for: .normal)

        sharingToggleButton.tintColor = isSharingLocation
            ? (Constants.purple ?? .systemBlue)
            : UIColor.black.withAlphaComponent(0.45)

        sharingToggleButton.setTitleColor(
            isSharingLocation ? (Constants.purple ?? .systemBlue) : UIColor.black.withAlphaComponent(0.45),
            for: .normal
        )
    }
    func setupEmptyRoutesView() {
        emptyRoutesView.addTo(view)

        NSLayoutConstraint.activate([
            emptyRoutesView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyRoutesView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            emptyRoutesView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 34),
            emptyRoutesView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -34)
        ])
    }

    func setupFriendCard() {
        mapDimControl.translatesAutoresizingMaskIntoConstraints = false
        mapDimControl.backgroundColor = UIColor.black.withAlphaComponent(0.12)
        mapDimControl.alpha = 0
        mapDimControl.isHidden = true
        mapDimControl.addTarget(self, action: #selector(onMapDimTapped), for: .touchUpInside)
        mapDimControl
            .addTo(view)
            .pinEdges(to: view)

        friendCardView.addTo(view)

        let tap = UITapGestureRecognizer(target: self, action: #selector(onFriendCardTapped))
        friendCardView.addGestureRecognizer(tap)

        NSLayoutConstraint.activate([
            friendCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            friendCardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            friendCardView.bottomAnchor.constraint(equalTo: stepsCardView.topAnchor, constant: -12),
            friendCardView.heightAnchor.constraint(equalToConstant: 92)
        ])
    }

    func setupScopeChips() {
        scopeChipsView.addTo(view)

        scopeChipsBottomConstraint = scopeChipsView.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: -176
        )

        NSLayoutConstraint.activate([
            scopeChipsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scopeChipsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scopeChipsView.heightAnchor.constraint(equalToConstant: 34),
            scopeChipsBottomConstraint!
        ])

        scopeChipsView.onAllFriendsTap = { [weak self] in
            guard let self else { return }

            self.viewModel.selectAllFriends()

            Task {
                await self.viewModel.reloadScopeData()
            }
        }

        scopeChipsView.onGroupTap = { [weak self] group in
            guard let self else { return }

            self.viewModel.selectGroup(group)

            Task {
                await self.viewModel.reloadScopeData()
            }
        }
    }

    func setupStepsCard() {
        stepsCardView.attach(to: view)

        stepsCardView.onRankingTap = { [weak self] in
            self?.onRankingTapped()
        }

        stepsCardView.onCollapseChanged = { [weak self] isCollapsed in
            guard let self else { return }

            self.scopeChipsBottomConstraint?.constant = isCollapsed ? -58 : -176

            UIView.animate(
                withDuration: 0.32,
                delay: 0,
                usingSpringWithDamping: 0.86,
                initialSpringVelocity: 0.5,
                options: [.curveEaseInOut]
            ) {
                self.view.layoutIfNeeded()
            }
        }

        if let snapshot = StepCountProvider.shared.cachedSnapshot() {
            stepsCardView.applyLocalSteps(snapshot.steps)
        }
    }

    func setupSignalBadge() {
        signalBadgeView.addTo(view)

        NSLayoutConstraint.activate([
            signalBadgeView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            signalBadgeView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14)
        ])

        applySignalBadge(.poor)
    }

    func bindViewModel() {
        viewModel.$groups
            .receive(on: DispatchQueue.main)
            .sink { [weak self] groups in
                guard let self else { return }
                self.scopeChipsView.configure(
                    groups: groups,
                    selectedScope: self.viewModel.selectedScope
                )
            }
            .store(in: &cancellables)

        viewModel.$selectedScope
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selectedScope in
                guard let self else { return }
                self.scopeChipsView.configure(
                    groups: self.viewModel.groups,
                    selectedScope: selectedScope
                )
                self.updateEmptyRoutesState(tracks: self.viewModel.visibleTracks)
            }
            .store(in: &cancellables)

        viewModel.$visibleUsers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] friends in
                self?.applyFriends(friends)
            }
            .store(in: &cancellables)

        viewModel.$visibleTracks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tracks in
                guard let self else { return }
                self.applyFriendTracks(tracks)
                self.updateEmptyRoutesState(tracks: tracks)
            }
            .store(in: &cancellables)

        viewModel.$ranking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ranking in
                guard let ranking else { return }
                self?.stepsCardView.applyRanking(ranking)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Signal Badge

private extension MapViewController {

    func applySignalBadge(_ quality: TrackQuality, location: CLLocation? = nil) {
        let location = location ?? trackingManager.currentLocation
        let isLost = isSignalLost()
        let effectiveQuality: TrackQuality = isLost ? .poor : quality
        let accuracy = location?.horizontalAccuracy

        currentSignalQuality = effectiveQuality
        signalBadgeView.apply(
            quality: effectiveQuality,
            title: signalTitle(quality: effectiveQuality, isLost: isLost),
            detail: signalDetail(
                accuracy: accuracy,
                confidenceScore: trackingManager.currentConfidenceScore,
                isLost: isLost
            )
        )

        applyAccuracyCircleStyle(quality: effectiveQuality, isLost: isLost)
        applyCurrentUserMarkerStyle(quality: effectiveQuality, isLost: isLost)
    }

    func isSignalLost() -> Bool {
        guard let lastLocationUpdateAt else { return true }
        return Date().timeIntervalSince(lastLocationUpdateAt) > signalLostAfter
    }

    func signalTitle(quality: TrackQuality, isLost: Bool) -> String {
        if isLost || quality == .poor {
            return "сигнал потерян"
        }

        return quality.badgeText
    }

    func signalDetail(
        accuracy: CLLocationAccuracy?,
        confidenceScore: Int,
        isLost: Bool
    ) -> String {
        if isLost {
            return "нет новых координат"
        }

        guard let accuracy, accuracy >= 0 else {
            return "доверие \(confidenceScore)%"
        }

        return "точность \(formatAccuracy(accuracy)) · \(confidenceScore)%"
    }

    func formatAccuracy(_ accuracy: CLLocationAccuracy) -> String {
        if accuracy >= 1000 {
            return "\(Int((accuracy / 1000).rounded())) км"
        }

        return "\(Int(accuracy.rounded())) м"
    }

    @objc func onSignalTimer() {
        applySignalBadge(currentSignalQuality)
    }
}

// MARK: - Polling

private extension MapViewController {

    func startFriendsPolling() {
        friendsTimer?.invalidate()
        friendsTimer = Timer.scheduledTimer(
            timeInterval: 12,
            target: self,
            selector: #selector(onFriendsTimer),
            userInfo: nil,
            repeats: true
        )
    }

    func stopFriendsPolling() {
        friendsTimer?.invalidate()
        friendsTimer = nil
    }

    func startSignalPolling() {
        signalTimer?.invalidate()
        signalTimer = Timer.scheduledTimer(
            timeInterval: 5,
            target: self,
            selector: #selector(onSignalTimer),
            userInfo: nil,
            repeats: true
        )
        signalTimer?.tolerance = 1
    }

    func stopSignalPolling() {
        signalTimer?.invalidate()
        signalTimer = nil
    }

    @objc func onFriendsTimer() {
        Task {
            await viewModel.reloadScopeData(includeRanking: false)
        }
    }

    func startLocalStepsUpdates() {
        guard isStepProviderActive == false else { return }
        isStepProviderActive = true

        if let snapshot = StepCountProvider.shared.cachedSnapshot() {
            stepsCardView.applyLocalSteps(snapshot.steps)
        }

        StepCountProvider.shared.start(
            onUpdate: { [weak self] snapshot in
                self?.stepsCardView.applyLocalSteps(snapshot.steps)
            },
            onUnavailable: { _ in }
        )
    }

    func stopLocalStepsUpdates() {
        guard isStepProviderActive else { return }
        isStepProviderActive = false
        StepCountProvider.shared.stop()
    }
}

// MARK: - Actions

private extension MapViewController {

    func onRankingTapped() {
        switch viewModel.selectedScope {
        case .allFriends:
            navDelegate?.onFriendsRankingTapped()

        case .group(let id, _):
            navDelegate?.onGroupRankingTapped(groupId: id)
        }
    }
    @objc func onCenterOnMeTapped() {
        guard let location = trackingManager.currentDisplayLocation ?? trackingManager.currentLocation else {
            let alert = UIAlertController(
                title: "Геопозиция пока не найдена",
                message: "Подожди пару секунд или проверь доступ к геолокации.",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        followedFriendId = nil
        isFollowModeEnabled = true
        hideFriendCard()
        applyFollowModeState()
        moveCamera(to: location, duration: 0.75, force: true)
    }
    @objc func onSharingToggleTapped() {
        isSharingLocation.toggle()
        trackingManager.setLocationSharingEnabled(isSharingLocation)
        applySharingToggleState()

        applyCurrentUserMarkerStyle(quality: currentSignalQuality, isLost: isSignalLost())

        guard let location = trackingManager.currentLocation else { return }

        Task {
            do {
                try await mapService.updateLiveLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    horizontalAccuracy: location.horizontalAccuracy,
                    speed: location.speed >= 0 ? location.speed : nil,
                    course: location.course >= 0 ? location.course : nil,
                    isSharing: isSharingLocation
                )
            } catch {
                print("Sharing toggle error:", error.localizedDescription)
            }
        }
    }
}

// MARK: - Camera

private extension MapViewController {

    func moveCamera(to location: CLLocation, duration: Float = 1) {
        let point = YMKPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        moveCamera(to: point, duration: duration)
    }

    func moveCamera(to location: CLLocation, duration: Float = 1, force: Bool) {
        let point = YMKPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        moveCamera(to: point, duration: duration, force: force)
    }

    func moveCamera(to point: YMKPoint, duration: Float = 1, force: Bool = false) {
        guard force || shouldMoveFollowCamera(to: point) else { return }

        lastFollowCameraPoint = point
        lastFollowCameraMoveAt = Date()

        let cameraPosition = YMKCameraPosition(
            target: point,
            zoom: 17,
            azimuth: 0,
            tilt: 0
        )

        mapView.mapWindow.map.move(
            with: cameraPosition,
            animation: YMKAnimation(type: .smooth, duration: duration),
            cameraCallback: nil
        )
    }

    func shouldMoveFollowCamera(to point: YMKPoint) -> Bool {
        guard let lastFollowCameraPoint,
              let lastFollowCameraMoveAt else {
            return true
        }

        let elapsed = Date().timeIntervalSince(lastFollowCameraMoveAt)
        let distance = CLLocation(
            latitude: lastFollowCameraPoint.latitude,
            longitude: lastFollowCameraPoint.longitude
        ).distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))

        return elapsed >= followCameraMinInterval || distance >= followCameraMinDistance
    }

    func followCurrentLocationIfNeeded(_ location: CLLocation) {
        guard isFollowModeEnabled, followedFriendId == nil else { return }
        moveCamera(to: location, duration: didMoveToUserLocation ? 0.55 : 1)
    }

    func followFriendIfNeeded(userId: Int, point: YMKPoint) {
        guard isFollowModeEnabled, followedFriendId == userId else { return }
        moveCamera(to: point, duration: 0.55)
    }

    func applyFollowModeState() {
        centerOnMeButton.backgroundColor = isFollowModeEnabled && followedFriendId == nil
            ? (Constants.purple ?? .systemBlue)
            : UIColor.white.withAlphaComponent(0.96)

        centerOnMeButton.tintColor = isFollowModeEnabled && followedFriendId == nil
            ? .white
            : (Constants.purple ?? .systemBlue)
    }
}

// MARK: - My Route

private extension MapViewController {

    func loadMyTrack() {
        Task { [weak self] in
            guard let self else { return }

            do {
                let segments = try await mapService.fetchMyMatchedTrack()
                await MainActor.run {
                    self.trackingManager.replaceTrack(with: segments)
                }
            } catch {
                print("My matched track fetch error:", error.localizedDescription)
            }
        }
    }

    func loadCurrentUserAvatar() {
        Task { [weak self] in
            guard let self else { return }

            do {
                let profile = try await mapService.fetchMyProfile()
                guard let avatarUrl = profile.avatarUrl, avatarUrl.isEmpty == false else { return }

                AvatarLoader.shared.load(urlString: avatarUrl) { [weak self] image in
                    guard let self, let image else { return }
                    self.currentUserAvatarImage = image
                    self.applyCurrentUserMarkerStyle(
                        quality: self.currentSignalQuality,
                        isLost: self.isSignalLost()
                    )
                }
            } catch {
                print("Current user avatar fetch error:", error.localizedDescription)
            }
        }
    }

    func scheduleMyRouteRedraw(with segments: [TrackSegment]) {
        pendingRouteSegments = segments

        let elapsed = Date().timeIntervalSince(lastRouteRedrawAt)
        guard elapsed < routeRedrawInterval else {
            routeRedrawWorkItem?.cancel()
            routeRedrawWorkItem = nil
            performPendingRouteRedraw()
            return
        }

        guard routeRedrawWorkItem == nil else { return }

        let delay = routeRedrawInterval - elapsed
        let workItem = DispatchWorkItem { [weak self] in
            self?.routeRedrawWorkItem = nil
            self?.performPendingRouteRedraw()
        }

        routeRedrawWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func performPendingRouteRedraw() {
        guard let segments = pendingRouteSegments else { return }
        pendingRouteSegments = nil
        lastRouteRedrawAt = Date()
        redrawMyRoute(with: segments)
    }

    func redrawMyRoute(with segments: [TrackSegment]) {
        for polyline in myRoutePolylines where polyline.isValid {
            mapView.mapWindow.map.mapObjects.remove(with: polyline)
        }
        myRoutePolylines.removeAll()

        for placemark in myRouteEventPlacemarks where placemark.isValid {
            mapView.mapWindow.map.mapObjects.remove(with: placemark)
        }
        myRouteEventPlacemarks.removeAll()

        var previousVisibleEnd: YMKPoint?
        var skippedReason: TrackBreakReason?

        for index in segments.indices {
            let sourceSegment = segments[index]
            var segment = TrackSimplification.simplifySegment(sourceSegment.points, minimumDistance: 6)
            segment = TrackSmoothing.smoothSegment(segment)
            segment = LightMapMatching.matchSegment(
                segment,
                quality: sourceSegment.quality,
                confidenceScore: sourceSegment.confidenceScore,
                movementKind: sourceSegment.movementKind
            )

            guard segment.count >= 2 else { continue }

            if !sourceSegment.isDrawableWalkSegment {
                skippedReason = sourceSegment.breakReason ?? breakReason(for: sourceSegment)
                if let first = segment.first {
                    addRouteEvent(
                        title: skippedReason?.eventTitle ?? sourceSegment.movementKind.labelText,
                        point: first,
                        color: eventColor(for: skippedReason, movementKind: sourceSegment.movementKind),
                        storeIn: &myRouteEventPlacemarks
                    )
                }
                continue
            }

            if let previousVisibleEnd, let currentStart = segment.first {
                addRouteGapIfNeeded(
                    from: previousVisibleEnd,
                    to: currentStart,
                    color: UIColor.black.withAlphaComponent(0.86),
                    strokeWidth: 4.8,
                    outlineWidth: 1.4,
                    zIndex: 7,
                    storeIn: &myRoutePolylines
                )

                if skippedReason != nil {
                    addRouteEvent(
                        title: "сигнал вернулся",
                        point: currentStart,
                        color: Constants.purple ?? .systemBlue,
                        storeIn: &myRouteEventPlacemarks
                    )
                    skippedReason = nil
                }
            }

            addGradientRouteSegment(
                points: segment,
                baseColor: Constants.orange ?? .systemOrange,
                quality: sourceSegment.quality,
                isNewest: index == segments.count - 1,
                zIndex: index == segments.count - 1 ? 12 : 9,
                storeIn: &myRoutePolylines
            )

            previousVisibleEnd = segment.last
        }

        updateEmptyRoutesState(tracks: viewModel.visibleTracks)
    }

    func myRouteColor(isNewest: Bool, quality: TrackQuality) -> UIColor {
        let base = Constants.orange ?? .systemOrange

        switch quality {
        case .good:
            return isNewest ? base.withAlphaComponent(0.95) : base.withAlphaComponent(0.68)
        case .weak:
            return base.withAlphaComponent(isNewest ? 0.62 : 0.42)
        case .poor:
            return .clear
        }
    }

    func addGradientRouteSegment(
        points: [YMKPoint],
        baseColor: UIColor,
        quality: TrackQuality,
        isNewest: Bool,
        zIndex: Float,
        storeIn polylines: inout [YMKPolylineMapObject]
    ) {
        guard points.count >= 2 else { return }

        for index in 0..<(points.count - 1) {
            let progress = Double(index + 1) / Double(max(points.count - 1, 1))
            let alphaBoost = isNewest ? 0.18 : 0
            let qualityAlpha = quality == .good ? 0.52 : 0.32
            let alpha = min(0.98, qualityAlpha + progress * 0.34 + alphaBoost)

            let polyline = YMKPolyline(points: [points[index], points[index + 1]])
            let object = mapView.mapWindow.map.mapObjects.addPolyline(with: polyline)
            let strokeColor = baseColor.withAlphaComponent(alpha)
            let outlineColor = UIColor.white.withAlphaComponent(isNewest ? 0.86 : 0.46)

            object.setStrokeColorWith(strokeColor)
            object.outlineColor = outlineColor
            object.outlineWidth = quality == .weak ? 1.1 : (isNewest ? 2.1 : 1.4)
            object.strokeWidth = quality == .weak ? 4.3 : (isNewest ? 6.8 : 5.2)
            object.zIndex = zIndex + Float(progress * 0.5)
            animateRoutePolylineAppearance(
                object,
                delay: min(0.42, Double(index) * 0.018),
                strokeColor: strokeColor,
                outlineColor: outlineColor
            )

            polylines.append(object)
        }
    }

    func addRouteEvent(
        title: String,
        point: YMKPoint,
        color: UIColor,
        storeIn placemarks: inout [YMKPlacemarkMapObject]
    ) {
        let image = FriendMarkerFactory.makeRouteEventImage(title: title, color: color)
        let placemark = mapView.mapWindow.map.mapObjects.addPlacemark(
            with: point,
            image: image
        )
        placemark.zIndex = 18
        placemarks.append(placemark)
    }

    func breakReason(for segment: TrackSegment) -> TrackBreakReason? {
        if segment.movementKind == .transport {
            return .vehicleJump
        }

        if segment.movementKind == .signalLost {
            return .lostSignal
        }

        if segment.quality == .poor {
            return .poorAccuracy
        }

        return segment.breakReason
    }

    func eventColor(for reason: TrackBreakReason?, movementKind: MapMovementKind) -> UIColor {
        switch reason {
        case .vehicleJump:
            return UIColor.systemIndigo
        case .poorAccuracy, .lostSignal, .staleLocation:
            return UIColor.systemGray
        case .appBackground:
            return UIColor.black.withAlphaComponent(0.58)
        case .none:
            return movementKind == .stationary ? (Constants.orange ?? .systemOrange) : UIColor.systemGray
        }
    }

    func addRouteGapIfNeeded(
        from start: YMKPoint,
        to end: YMKPoint,
        color: UIColor,
        strokeWidth: Float,
        outlineWidth: Float,
        zIndex: Float,
        storeIn polylines: inout [YMKPolylineMapObject]
    ) {
        let distance = CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))

        guard distance >= 25 else { return }

        let polyline = YMKPolyline(points: [start, end])
        let object = mapView.mapWindow.map.mapObjects.addPolyline(with: polyline)
        let outlineColor = UIColor.white.withAlphaComponent(0.78)

        object.setStrokeColorWith(color)
        object.outlineColor = outlineColor
        object.outlineWidth = outlineWidth
        object.strokeWidth = strokeWidth
        object.dashLength = 14
        object.gapLength = 10
        object.zIndex = zIndex
        pulseApproximateRouteGap(object, strokeColor: color, outlineColor: outlineColor)

        polylines.append(object)
    }

    func animateRoutePolylineAppearance(
        _ object: YMKPolylineMapObject,
        delay: TimeInterval,
        strokeColor: UIColor,
        outlineColor: UIColor
    ) {
        object.setStrokeColorWith(routeColor(strokeColor, alphaMultiplier: 0))
        object.outlineColor = routeColor(outlineColor, alphaMultiplier: 0)

        for step in 1...4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + Double(step) * 0.035) {
                guard object.isValid else { return }
                let multiplier = CGFloat(step) / 4
                object.setStrokeColorWith(self.routeColor(strokeColor, alphaMultiplier: multiplier))
                object.outlineColor = self.routeColor(outlineColor, alphaMultiplier: multiplier)
            }
        }
    }

    func pulseApproximateRouteGap(
        _ object: YMKPolylineMapObject,
        strokeColor: UIColor,
        outlineColor: UIColor
    ) {
        object.setStrokeColorWith(routeColor(strokeColor, alphaMultiplier: 0.42))
        object.outlineColor = routeColor(outlineColor, alphaMultiplier: 0.42)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            guard object.isValid else { return }
            object.setStrokeColorWith(self.routeColor(strokeColor, alphaMultiplier: 1))
            object.outlineColor = self.routeColor(outlineColor, alphaMultiplier: 1)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
            guard object.isValid else { return }
            object.setStrokeColorWith(self.routeColor(strokeColor, alphaMultiplier: 0.82))
            object.outlineColor = self.routeColor(outlineColor, alphaMultiplier: 0.82)
        }
    }

    func routeColor(_ color: UIColor, alphaMultiplier: CGFloat) -> UIColor {
        let resolvedColor = color.resolvedColor(with: traitCollection)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1

        if resolvedColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(
                red: red,
                green: green,
                blue: blue,
                alpha: max(0, min(1, alpha * alphaMultiplier))
            )
        }

        return resolvedColor.withAlphaComponent(max(0, min(1, alphaMultiplier)))
    }
}

// MARK: - Current User Marker

private extension MapViewController {

    func updateCurrentUserMarker(with location: CLLocation) {
        lastLocationUpdateAt = Date()

        let point = YMKPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        currentUserDisplayPoint = point

        updateCurrentUserAccuracyCircle(with: location, point: point)
        updateCurrentUserPulseCircle(point: point)

        if let currentUserPlacemark, currentUserPlacemark.isValid {
            currentUserPlacemark.geometry = point
            currentUserPlacemark.zIndex = 30
            applyCurrentUserMarkerStyle(quality: currentSignalQuality, isLost: isSignalLost())
            return
        }

        let image = FriendMarkerFactory.makeCurrentUserLiveImage()
        let placemark = mapView.mapWindow.map.mapObjects.addPlacemark(
            with: point,
            image: image
        )
        placemark.zIndex = 30
        currentUserPlacemark = placemark
        applyCurrentUserMarkerStyle(quality: currentSignalQuality, isLost: isSignalLost())
        updateEmptyRoutesState(tracks: viewModel.visibleTracks)
    }

    func updateCurrentUserAccuracyCircle(with location: CLLocation, point: YMKPoint) {
        guard location.horizontalAccuracy >= 0 else {
            currentUserAccuracyCircle?.isVisible = false
            return
        }

        let radius = min(max(location.horizontalAccuracy, 12), maximumAccuracyCircleRadius)
        let circle = YMKCircle(center: point, radius: Float(radius))

        if let currentUserAccuracyCircle, currentUserAccuracyCircle.isValid {
            currentUserAccuracyCircle.geometry = circle
            currentUserAccuracyCircle.isVisible = true
        } else {
            let object = mapView.mapWindow.map.mapObjects.addCircle(with: circle)
            object.isGeodesic = true
            object.zIndex = 24
            currentUserAccuracyCircle = object
        }

        applyAccuracyCircleStyle(
            quality: TrackQuality.from(location: location),
            isLost: isSignalLost()
        )
    }

    func applyAccuracyCircleStyle(quality: TrackQuality, isLost: Bool) {
        guard let currentUserAccuracyCircle, currentUserAccuracyCircle.isValid else { return }

        if isLost || quality == .poor {
            currentUserAccuracyCircle.fillColor = UIColor.systemGray.withAlphaComponent(0.10)
            currentUserAccuracyCircle.strokeColor = UIColor.systemGray.withAlphaComponent(0.34)
            currentUserAccuracyCircle.strokeWidth = 1.8
            return
        }

        switch quality {
        case .good:
            let base = Constants.purple ?? .systemBlue
            currentUserAccuracyCircle.fillColor = base.withAlphaComponent(0.10)
            currentUserAccuracyCircle.strokeColor = base.withAlphaComponent(0.32)
            currentUserAccuracyCircle.strokeWidth = 1.4

        case .weak:
            let base = Constants.orange ?? .systemOrange
            currentUserAccuracyCircle.fillColor = base.withAlphaComponent(0.12)
            currentUserAccuracyCircle.strokeColor = base.withAlphaComponent(0.38)
            currentUserAccuracyCircle.strokeWidth = 1.6

        case .poor:
            currentUserAccuracyCircle.fillColor = UIColor.systemGray.withAlphaComponent(0.10)
            currentUserAccuracyCircle.strokeColor = UIColor.systemGray.withAlphaComponent(0.34)
            currentUserAccuracyCircle.strokeWidth = 1.8
        }
    }

    func updateCurrentUserPulseCircle(point: YMKPoint) {
        let circle = YMKCircle(center: point, radius: 16)

        if let currentUserPulseCircle, currentUserPulseCircle.isValid {
            currentUserPulseCircle.geometry = circle
        } else {
            let object = mapView.mapWindow.map.mapObjects.addCircle(with: circle)
            object.isGeodesic = true
            object.zIndex = 23
            currentUserPulseCircle = object
        }

        applyPulseVisibility()
    }

    func applyCurrentUserMarkerStyle(quality: TrackQuality, isLost: Bool) {
        let muted = isLost || quality == .poor || !isSharingLocation
        currentUserPlacemark?.opacity = muted ? 0.58 : 1
        let ringColor = muted
            ? UIColor.systemGray
            : (Constants.orange ?? .systemOrange)

        if let currentUserAvatarImage {
            currentUserPlacemark?.setIconWith(
                FriendMarkerFactory.makeCurrentUserLiveAvatarImage(
                    currentUserAvatarImage,
                    ringColor: ringColor
                )
            )
        } else {
            currentUserPlacemark?.setIconWith(
                FriendMarkerFactory.makeCurrentUserLiveImage(
                    username: "Я",
                    ringColor: ringColor
                )
            )
        }

        applyPulseVisibility()
    }

    func applyPulseVisibility() {
        let shouldPulse = currentSignalQuality == .good &&
            !isSignalLost() &&
            isSharingLocation &&
            currentUserDisplayPoint != nil

        currentUserPulseCircle?.isVisible = shouldPulse

        if shouldPulse {
            startPulseIfNeeded()
        } else {
            stopPulse()
        }
    }

    func startPulseIfNeeded() {
        guard pulseDisplayLink == nil else { return }

        pulseStartedAt = Date()
        let displayLink = CADisplayLink(target: self, selector: #selector(onPulseFrame))
        displayLink.add(to: .main, forMode: .common)
        pulseDisplayLink = displayLink
    }

    func stopPulse() {
        pulseDisplayLink?.invalidate()
        pulseDisplayLink = nil
        currentUserPulseCircle?.isVisible = false
    }

    @objc func onPulseFrame() {
        guard let currentUserPulseCircle,
              currentUserPulseCircle.isValid,
              let currentUserDisplayPoint else { return }

        let elapsed = Date().timeIntervalSince(pulseStartedAt)
        let progress = (elapsed.truncatingRemainder(dividingBy: 1.8)) / 1.8
        let radius = Float(18 + progress * 30)
        let alpha = CGFloat(max(0, 0.18 * (1 - progress)))

        currentUserPulseCircle.geometry = YMKCircle(
            center: currentUserDisplayPoint,
            radius: radius
        )
        currentUserPulseCircle.fillColor = (Constants.orange ?? .systemOrange).withAlphaComponent(alpha)
        currentUserPulseCircle.strokeColor = (Constants.orange ?? .systemOrange).withAlphaComponent(alpha * 1.4)
        currentUserPulseCircle.strokeWidth = 1.2
    }
}

// MARK: - Friends Markers

private extension MapViewController {

    func applyFriends(_ friends: [FriendLiveLocation]) {
        guard isMapScreenActive else { return }

        let visibleFriends = friends.filter { !$0.isMe }
        let incomingIds = Set(visibleFriends.map { $0.userId })
        AvatarLoader.shared.prefetch(urlStrings: visibleFriends.compactMap(\.avatarUrl))

        for (userId, placemark) in friendPlacemarks where !incomingIds.contains(userId) {
            if placemark.isValid {
                mapView.mapWindow.map.mapObjects.remove(with: placemark)
            }
            if selectedFriend?.userId == userId {
                hideFriendCard()
            }
            friendPlacemarks.removeValue(forKey: userId)
            currentFriendAvatarUrls.removeValue(forKey: userId)
            friendTapListeners.removeValue(forKey: userId)
        }

        for friend in visibleFriends {
            let point = YMKPoint(latitude: friend.latitude, longitude: friend.longitude)
            let fallbackImage = FriendMarkerFactory.makeFriendLiveFallbackImage(username: friend.username)

            if let existing = friendPlacemarks[friend.userId], existing.isValid {
                movePlacemarkSmoothly(
                    userId: friend.userId,
                    placemark: existing,
                    to: point
                )
                followFriendIfNeeded(userId: friend.userId, point: point)
                existing.zIndex = 22
                existing.opacity = friendMarkerOpacity(friend)
                existing.userData = friend

                if selectedFriend?.userId == friend.userId {
                    selectedFriend = friend
                    friendCardView.configure(with: friend)
                }

                let previousUrl = currentFriendAvatarUrls[friend.userId]
                if previousUrl != friend.avatarUrl {
                    currentFriendAvatarUrls[friend.userId] = friend.avatarUrl
                    existing.setIconWith(fallbackImage)
                    loadAvatarIfNeeded(for: friend)
                }
                continue
            }

            let placemark = mapView.mapWindow.map.mapObjects.addPlacemark(
                with: point,
                image: fallbackImage
            )
            placemark.zIndex = 22
            placemark.opacity = friendMarkerOpacity(friend)
            placemark.userData = friend

            let tapListener = MapFriendTapListener { [weak self] friend in
                self?.showFriendCard(friend)
            }
            placemark.addTapListener(with: tapListener)

            friendTapListeners[friend.userId] = tapListener
            friendPlacemarks[friend.userId] = placemark
            currentFriendAvatarUrls[friend.userId] = friend.avatarUrl

            loadAvatarIfNeeded(for: friend)
        }

        updateEmptyRoutesState(tracks: viewModel.visibleTracks)
    }

    func loadAvatarIfNeeded(for friend: FriendLiveLocation) {
        guard let avatarUrl = friend.avatarUrl, !avatarUrl.isEmpty else { return }

        AvatarLoader.shared.load(urlString: avatarUrl) { [weak self] image in
            guard let self else { return }
            guard self.isMapScreenActive else { return }
            guard let image else { return }
            guard self.currentFriendAvatarUrls[friend.userId] == avatarUrl else { return }

            let markerImage = FriendMarkerFactory.makeFriendLiveAvatarImage(
                image,
                username: friend.username
            )

            DispatchQueue.main.async {
                guard self.isMapScreenActive else { return }
                guard let placemark = self.friendPlacemarks[friend.userId] else { return }
                guard placemark.isValid else { return }

                placemark.setIconWith(markerImage)
                placemark.zIndex = 22
            }
        }
    }

    func updateFriendPlacemarkPosition(
        userId: Int,
        username: String,
        avatarUrl: String?,
        point: YMKPoint
    ) {
        guard isMapScreenActive else { return }

        let friend = FriendLiveLocation(
            userId: userId,
            username: username,
            avatarUrl: avatarUrl,
            latitude: point.latitude,
            longitude: point.longitude,
            updatedAt: "",
            isMe: false
        )

        if let placemark = friendPlacemarks[userId], placemark.isValid {
            movePlacemarkSmoothly(
                userId: userId,
                placemark: placemark,
                to: point
            )
            followFriendIfNeeded(userId: userId, point: point)
            placemark.zIndex = 22
            placemark.opacity = friendMarkerOpacity(friend)
            placemark.userData = friend

            let previousUrl = currentFriendAvatarUrls[userId]
            if previousUrl != avatarUrl {
                currentFriendAvatarUrls[userId] = avatarUrl
                placemark.setIconWith(FriendMarkerFactory.makeFriendLiveFallbackImage(username: username))
                loadAvatarIfNeeded(for: friend)
            }

            return
        }

        let fallbackImage = FriendMarkerFactory.makeFriendLiveFallbackImage(username: username)

        let placemark = mapView.mapWindow.map.mapObjects.addPlacemark(
            with: point,
            image: fallbackImage
        )

        placemark.zIndex = 22
        placemark.opacity = friendMarkerOpacity(friend)
        placemark.userData = friend

        let tapListener = MapFriendTapListener { [weak self] friend in
            self?.showFriendCard(friend)
        }

        placemark.addTapListener(with: tapListener)

        friendTapListeners[userId] = tapListener
        friendPlacemarks[userId] = placemark
        currentFriendAvatarUrls[userId] = avatarUrl

        loadAvatarIfNeeded(for: friend)
        updateEmptyRoutesState(tracks: viewModel.visibleTracks)
    }

    func friendMarkerOpacity(_ friend: FriendLiveLocation) -> Float {
        let quality = trackQuality(from: friend.signalQuality)
        let isStale = (friend.mapUpdatedAtDate ?? .distantPast).timeIntervalSinceNow < -5 * 60
        return (quality == .poor || isStale) ? 0.68 : 1
    }
}

// MARK: - Friends Routes

private extension MapViewController {

    func applyFriendTracks(_ tracks: [FriendMatchedTrackResponse]) {
        guard isMapScreenActive else { return }

        let incomingIds = Set(tracks.map { $0.userId })
        AvatarLoader.shared.prefetch(urlStrings: tracks.compactMap(\.avatarUrl))

        for (userId, polylines) in friendRoutePolylines where !incomingIds.contains(userId) {
            for polyline in polylines where polyline.isValid {
                mapView.mapWindow.map.mapObjects.remove(with: polyline)
            }
            friendRoutePolylines.removeValue(forKey: userId)
        }

        for track in tracks {
            if let existing = friendRoutePolylines[track.userId] {
                for polyline in existing where polyline.isValid {
                    mapView.mapWindow.map.mapObjects.remove(with: polyline)
                }
                friendRoutePolylines.removeValue(forKey: track.userId)
            }

            var createdPolylines: [YMKPolylineMapObject] = []
            var lastPointForMarker: YMKPoint?
            var previousVisibleEnd: YMKPoint?

            for index in track.segments.indices {
                let segmentResponse = track.segments[index]
                let points = segmentResponse.displayPoints.map {
                    YMKPoint(latitude: $0.latitude, longitude: $0.longitude)
                }

                guard points.count >= 2 else { continue }

                let sourceQuality: TrackQuality
                sourceQuality = trackQuality(from: segmentResponse.signalQuality)
                let movementKind = mapMovementKind(from: segmentResponse.movementKind ?? segmentResponse.movementState)
                let breakReason = trackBreakReason(from: segmentResponse.breakReason)
                let confidenceScore = segmentResponse.confidenceScore ?? confidenceScore(from: segmentResponse.matchingConfidence)

                if sourceQuality == .poor || !movementKind.isRouteDrawable || breakReason != nil {
                    continue
                }

                let simplified = TrackSimplification.simplifySegment(points, minimumDistance: 6)
                let smoothed = TrackSmoothing.smoothSegment(simplified)
                let matched = LightMapMatching.matchSegment(
                    smoothed,
                    quality: sourceQuality,
                    confidenceScore: confidenceScore,
                    movementKind: movementKind
                )

                guard matched.count >= 2 else { continue }

                if let previousVisibleEnd, let currentStart = matched.first {
                    addRouteGapIfNeeded(
                        from: previousVisibleEnd,
                        to: currentStart,
                        color: UIColor.black.withAlphaComponent(0.76),
                        strokeWidth: 3.4,
                        outlineWidth: 1.0,
                        zIndex: 5,
                        storeIn: &createdPolylines
                    )
                }

                let isNewest = index == track.segments.count - 1
                addGradientRouteSegment(
                    points: matched,
                    baseColor: UIColor.systemBlue,
                    quality: sourceQuality,
                    isNewest: isNewest,
                    zIndex: isNewest ? 8 : 6,
                    storeIn: &createdPolylines
                )
                lastPointForMarker = matched.last
                previousVisibleEnd = matched.last
            }

            friendRoutePolylines[track.userId] = createdPolylines

            if let lastPointForMarker {
                updateFriendPlacemarkPosition(
                    userId: track.userId,
                    username: track.username,
                    avatarUrl: track.avatarUrl,
                    point: lastPointForMarker
                )
            }
        }
    }

    func friendRouteColor(isNewest: Bool, quality: TrackQuality) -> UIColor {
        let base = UIColor.systemBlue

        switch quality {
        case .good:
            return isNewest ? base.withAlphaComponent(0.88) : base.withAlphaComponent(0.55)
        case .weak:
            return base.withAlphaComponent(isNewest ? 0.48 : 0.30)
        case .poor:
            return .clear
        }
    }

    func trackQuality(from rawValue: String?) -> TrackQuality {
        switch rawValue {
        case "good":
            return .good
        case "weak":
            return .weak
        case "poor":
            return .poor
        default:
            return .weak
        }
    }

    func mapMovementKind(from rawValue: String?) -> MapMovementKind {
        MapMovementKind.fromLiveValue(rawValue)
    }

    func trackBreakReason(from rawValue: String?) -> TrackBreakReason? {
        guard let rawValue else { return nil }
        return TrackBreakReason(rawValue: rawValue)
    }

    func confidenceScore(from matchingConfidence: String?) -> Int {
        switch matchingConfidence {
        case "high":
            return 86
        case "medium":
            return 58
        case "low":
            return 24
        default:
            return 55
        }
    }
}

// MARK: - Friend Card

private extension MapViewController {

    func showFriendCard(_ friend: FriendLiveLocation) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        selectedFriend = friend
        followedFriendId = friend.userId
        isFollowModeEnabled = true
        applyFollowModeState()
        friendCardView.configure(with: friend)

        let point = YMKPoint(latitude: friend.latitude, longitude: friend.longitude)
        moveCamera(to: point, duration: 0.65, force: true)

        mapDimControl.isHidden = false
        mapDimControl.alpha = 0
        friendCardView.isHidden = false
        friendCardView.transform = CGAffineTransform(translationX: 0, y: 32)
            .scaledBy(x: 0.98, y: 0.98)

        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.62,
            options: [.curveEaseOut]
        ) {
            self.mapDimControl.alpha = 1
            self.friendCardView.alpha = 1
            self.friendCardView.transform = .identity
        }
    }

    func hideFriendCard() {
        selectedFriend = nil
        followedFriendId = nil

        UIView.animate(withDuration: 0.18) {
            self.mapDimControl.alpha = 0
            self.friendCardView.alpha = 0
            self.friendCardView.transform = CGAffineTransform(translationX: 0, y: 28)
        } completion: { _ in
            self.mapDimControl.isHidden = true
            self.friendCardView.isHidden = true
            self.friendCardView.transform = .identity
        }
    }

    @objc func onFriendCardTapped() {
        guard let selectedFriend else { return }
        onFriendTap?(selectedFriend)
    }

    @objc func onMapDimTapped() {
        hideFriendCard()
    }
}

// MARK: - Alerts

private extension MapViewController {

    func showLocationDeniedAlert() {
        let alert = UIAlertController(
            title: "Нет доступа к геолокации",
            message: "Разреши доступ к геолокации в настройках, чтобы приложение могло показывать тебя на карте.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - TrackingManagerObserver

extension MapViewController: TrackingManagerObserver {

    func trackingManager(_ manager: TrackingManager, didUpdateCurrentLocation location: CLLocation) {
        if !didMoveToUserLocation {
            didMoveToUserLocation = true
        }

        updateCurrentUserMarker(with: location)
        followCurrentLocationIfNeeded(location)
    }

    func trackingManager(_ manager: TrackingManager, didUpdateTrackSegments segments: [TrackSegment]) {
        scheduleMyRouteRedraw(with: segments)
    }

    func trackingManager(_ manager: TrackingManager, didUpdateSignalQuality quality: TrackQuality) {
        applySignalBadge(quality)
    }

    func trackingManagerDidDenyAccess(_ manager: TrackingManager) {
        showLocationDeniedAlert()
    }
}

// MARK: - Empty State

private extension MapViewController {

    func updateEmptyRoutesState(tracks: [FriendMatchedTrackResponse]) {
        let hasAnyTrackData = tracks.contains { track in
            track.segments.contains { segment in
                let kind = mapMovementKind(from: segment.movementKind ?? segment.movementState)
                return segment.displayPoints.count >= 2 || kind != .unknown
            }
        }

        let hasOwnRoute = myRoutePolylines.contains { $0.isValid }
        let hasFriendRoute = friendRoutePolylines.values.flatMap { $0 }.contains { $0.isValid }
        let hasCurrentUser = currentUserPlacemark?.isValid == true
        let hasFriendMarkers = friendPlacemarks.values.contains { $0.isValid }
        let hasAnyMapContent = hasOwnRoute ||
            hasFriendRoute ||
            hasCurrentUser ||
            hasFriendMarkers ||
            hasAnyTrackData

        let shouldShow = !hasAnyMapContent

        switch viewModel.selectedScope {
        case .allFriends:
            emptyRoutesView.configure(
                title: "Пока нет маршрутов",
                subtitle: "Когда друзья начнут гулять, их маршруты появятся здесь"
            )

        case .group:
            emptyRoutesView.configure(
                title: "В группе пока нет маршрутов",
                subtitle: "Когда участники группы начнут гулять, их маршруты появятся здесь"
            )
        }

        if shouldShow {
            emptyRoutesView.isHidden = false

            UIView.animate(withDuration: 0.22) {
                self.emptyRoutesView.alpha = 1
            }
        } else {
            UIView.animate(withDuration: 0.18) {
                self.emptyRoutesView.alpha = 0
            } completion: { _ in
                self.emptyRoutesView.isHidden = true
            }
        }
    }
}

// MARK: - Placemark Animation

private extension MapViewController {

    func movePlacemarkSmoothly(
        userId: Int,
        placemark: YMKPlacemarkMapObject,
        to point: YMKPoint,
        duration: TimeInterval = 0.75
    ) {
        guard placemark.isValid else { return }

        let from = placemark.geometry

        let distance = CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))

        guard distance > 2 else {
            placemark.geometry = point
            return
        }

        placemarkAnimations[userId]?.invalidate()

        placemarkAnimationStarts[userId] = Date()
        placemarkAnimationFromPoints[userId] = from
        placemarkAnimationToPoints[userId] = point

        let displayLink = CADisplayLink(target: self, selector: #selector(onPlacemarkAnimationFrame(_:)))
        displayLink.add(to: .main, forMode: .common)

        placemarkAnimations[userId] = displayLink
    }

    @objc func onPlacemarkAnimationFrame(_ displayLink: CADisplayLink) {
        guard let pair = placemarkAnimations.first(where: { $0.value === displayLink }) else {
            displayLink.invalidate()
            return
        }

        let userId = pair.key

        guard let placemark = friendPlacemarks[userId],
              placemark.isValid,
              let startedAt = placemarkAnimationStarts[userId],
              let from = placemarkAnimationFromPoints[userId],
              let to = placemarkAnimationToPoints[userId] else {
            displayLink.invalidate()
            placemarkAnimations[userId] = nil
            return
        }

        let progress = min(Date().timeIntervalSince(startedAt) / 0.75, 1)
        let eased = 1 - pow(1 - progress, 3)

        placemark.geometry = YMKPoint(
            latitude: from.latitude + (to.latitude - from.latitude) * eased,
            longitude: from.longitude + (to.longitude - from.longitude) * eased
        )

        if progress >= 1 {
            placemark.geometry = to
            displayLink.invalidate()

            placemarkAnimations[userId] = nil
            placemarkAnimationStarts[userId] = nil
            placemarkAnimationFromPoints[userId] = nil
            placemarkAnimationToPoints[userId] = nil
        }
    }
}
