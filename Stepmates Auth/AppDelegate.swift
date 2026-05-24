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
        
        let networkHandler = NetworkHandler()
        let tokenStorage = AccessTokenStorage()
        let mapService = MapService(networkHandler: networkHandler, tokenStorage: tokenStorage)

        TrackingManager.shared.configure(mapService: mapService)
        TrackingManager.shared.start()
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        TrackingManager.shared.flushPendingTrackPoints()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        TrackingManager.shared.flushPendingTrackPoints()
    }
}

private extension AppDelegate {
    func setupYandexMapKit() {
        YMKMapKit.setApiKey("49293477-49bb-4147-8be5-04e9ca5b077c")
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
