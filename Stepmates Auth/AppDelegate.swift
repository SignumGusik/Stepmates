//
//  AppDelegate.swift
//  Stepmates Auth
//
//  Created by Диана on 23/01/2026.
//

import UIKit
import YandexMapsMobile
import CoreLocation

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var appNavCoordinator: AppNavCoordinator!
    var window: UIWindow?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return true
        }
        
        setupYandexMapKit()
        
        window = UIWindow(frame: UIScreen.main.bounds)
        
        guard let window else { return true }
    
        appNavCoordinator = AppNavCoordinator(window: window)
        appNavCoordinator.start()
        configureNavigationBar()
        
        let tokenStorage = AccessTokenStorage()
        let networkHandler = NetworkHandler(tokenStorage: tokenStorage)
        let mapService = MapService(networkHandler: networkHandler, tokenStorage: tokenStorage)

        TrackingManager.shared.configure(mapService: mapService)
        TrackingManager.shared.start()
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        StepSyncManager.shared.syncRecentDays(reason: "launch")
        
        return true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        StepSyncManager.shared.syncRecentDays(reason: "foreground")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        TrackingManager.shared.flushPendingTrackPoints()
        StepSyncManager.shared.syncRecentDays(reason: "background")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        TrackingManager.shared.flushPendingTrackPoints()
        StepSyncManager.shared.syncRecentDays(reason: "terminate", force: true)
    }

    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        StepSyncManager.shared.syncRecentDays(reason: "background_fetch", force: true) { didSync in
            completionHandler(didSync ? .newData : .noData)
        }
    }
}

private extension AppDelegate {
    func setupYandexMapKit() {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "YANDEX_MAPKIT_API_KEY") as? String,
              apiKey.isEmpty == false,
              apiKey.contains("$(") == false else {
            assertionFailure("YANDEX_MAPKIT_API_KEY is missing. Add it to local build settings before running the app.")
            return
        }

        YMKMapKit.setApiKey(apiKey)
        YMKMapKit.sharedInstance()
    }
}

extension AppDelegate {
    private func configureNavigationBar() {
        let arrow = UIImage(named: "backArrow")?
            .withRenderingMode(.alwaysOriginal)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .white

        appearance.setBackIndicatorImage(arrow, transitionMaskImage: arrow)
        appearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        appearance.backButtonAppearance.highlighted.titleTextAttributes = [.foregroundColor: UIColor.clear]

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.tintColor = .black
    }
}
