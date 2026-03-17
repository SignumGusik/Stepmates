//
//  UIViewControllerExtensions.swift
//  Stepmates Auth
//
//  Created by Диана on 24/01/2026.
//

import UIKit

extension UIViewController {
    
    func showOkAlert(title: String?, message: String? = nil, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .cancel) { _ in completion?() }
        alert.addAction(okAction)
        present(alert, animated: true)
    }
}
