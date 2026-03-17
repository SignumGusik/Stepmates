//
//  SettingsViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 17/03/2026.
//

import UIKit

extension SettingsViewController {
    final class ViewModel {
        let username: String
        let avatarColor: UIColor
        
        init(username: String) {
            self.username = username
            self.avatarColor = ViewModel.randomColor(for: username)
        }
        
        private static func randomColor(for username: String) -> UIColor {
            let colors: [UIColor] = [
                Constants.purple ?? .systemBlue,
                Constants.orange ?? .orange,
                Constants.blue ?? .blue,
                UIColor(hex: "#D8DDF8") ?? .systemGray4,
                UIColor(hex: "#000000") ?? .black,
                UIColor(hex: "#D7A692") ?? .brown
            ]
            
            let index = abs(username.hashValue) % colors.count
            return colors[index]
        }
    }
}
