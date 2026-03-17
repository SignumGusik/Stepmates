//
//  RegisterViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 24/01/2026.
//

import UIKit

protocol RegisterNavDelegate: AnyObject {
    func onRegistrationComplete()
    func onLoginTapped()
    
}

class RegisterViewController: UIViewController {
    private lazy var emailTextField = UITextField.makeEmailField(delegate: self)
    private lazy var passwordTextField = UITextField.makePasswordField(delegate: self)
    private lazy var confirmPasswordTextField = UITextField.makePasswordField(placeholder: "Confirm password", delegate: self)
    private lazy var registerButton = UIButton.makeButton(title: "Register", target: self, action: #selector(self.onRegisterTapped))
    
    private lazy var loginButton = UIButton.makeButton(title: "Login", target: self, action: #selector(self.onLoginTapped))
    
    weak var navDelegate: RegisterNavDelegate?
    private let viewModel: ViewModel
    required init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }
    
    
}

// MARK: - Lifecycle
extension RegisterViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        
    }
    
    
    
    
}
// MARK: - View Setup/Registration
extension RegisterViewController {
    
    func setupViews() {
        title = "Register"
        view.backgroundColor = .white
        
        emailTextField
            .addTo(view)
            .centerOn(view)
            .setDefaultFieldSize(superview: view)
        
        passwordTextField
            .addTo(view)
            .centerXOn(view)
            .pinTop(toAnchor: emailTextField.bottomAnchor, constant: 10)
        
        confirmPasswordTextField
            .addTo(view)
            .centerXOn(view)
            .pinTop(toAnchor: passwordTextField.bottomAnchor, constant: 10)
            .setDefaultFieldSize(superview: view)
        
        loginButton
            .addTo(view)
            .centerXOn(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        
        registerButton
            .addTo(view)
            .centerXOn(view)
            .pinTop(toAnchor: confirmPasswordTextField.bottomAnchor, constant: 10)
        
        
    }
    
}

// MARK: - Actions
extension RegisterViewController {
    
    @objc func onRegisterTapped() {
        viewModel.email = emailTextField.text
        viewModel.password = passwordTextField.text
        viewModel.confirmPassword = confirmPasswordTextField.text
        Task {
            do {
                try await viewModel.submitRegister()
                await MainActor.run {
                    [weak self] in
                    self?.showOkAlert(title: "Registered", message: "Activation email sent to \(viewModel.email!)") {
                        self?.navDelegate?.onRegistrationComplete()}
                }
                
            } catch {
                await MainActor.run {
                    [weak self] in
                    self?.showOkAlert(title:"Error", message: error.localizedDescription)
                }
            }
        }
        
    }
    @objc func onLoginTapped() {
        navDelegate?.onLoginTapped()
        
    }
}

// MARK:
extension RegisterViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            confirmPasswordTextField.becomeFirstResponder()
        } else {
            view.endEditing(true)
        }
        return false
    }
}
