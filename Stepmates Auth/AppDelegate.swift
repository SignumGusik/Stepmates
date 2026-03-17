//
//  AppDelegate.swift
//  Stepmates Auth
//
//  Created by Диана on 23/01/2026.
//

import UIKit

@main



class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var appNavCoordinator: AppNavCoordinator!
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return true
        }
        // Override point for customization after application launch.
        
        window = UIWindow(frame: UIScreen.main.bounds)
        appNavCoordinator = AppNavCoordinator(window: window!)
        appNavCoordinator.start()
        configureNavigationBar()
        return true
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

