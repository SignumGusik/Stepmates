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
        // Override point for customization after application launch.
        
        window = UIWindow(frame: UIScreen.main.bounds)
        appNavCoordinator = AppNavCoordinator(window: window!)
        appNavCoordinator.start()
        return true
    }


}

