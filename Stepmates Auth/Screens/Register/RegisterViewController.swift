//
//  RegisterViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 24/01/2026.
//

import UIKit

protocol RegisterNavDelegate: AnyObject {
    func onRegistrationCodeSent(email: String)
    func onLoginTapped()
}

class RegisterViewController: UIViewController {
    private lazy var backButton = UIButton.makeBackButton(
            target: self,
            action: #selector(onBackTapped)
    )
    internal lazy var registerTitle = UILabel.makeTitle(text: "Создать аккаунт")
    
    private lazy var subtitleLabel = UILabel.makeManrope(text: "Создайте аккаунт, чтобы ходить с друзьями", style: Constants.manropeMedium, size: 14)
    private lazy var emailLabel = UILabel.makeManrope(text: "Почта:", style: Constants.manropeMedium, size: 16)
    
    private lazy var emailTextField = UITextField.makeEmailField(delegate: self)
    private lazy var passwordTextField = UITextField.makePasswordField(placeholder: "Придумайте пароль:", delegate: self)
    private lazy var confirmPasswordTextField = UITextField.makePasswordField(placeholder: "Повторите пароль:", delegate: self)
    private lazy var registerButton = UIButton.makePrimaryBigButton(
        title: "Бежать дальше",
        target: self,
        action: #selector(self.onRegisterTapped)
    )
    
    private lazy var loginButton = UIButton.makeLinkButton(
        title: "Уже есть аккаунт? Войти",
        target: self,
        action: #selector(self.onLoginTapped)
    )
    
    
    
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
        passwordTextField.attachPasswordVisibilityToggle(
            target: self,
            action: #selector(onEyeTapped(_:)),
            tag: 1
        )
        confirmPasswordTextField.attachPasswordVisibilityToggle(
            target: self,
            action: #selector(onEyeTapped(_:)),
            tag: 2
        )
    }
    
    
    
    
}
// MARK: - View Setup/Registration
extension RegisterViewController {
    
    func setupViews() {
        applyStepmatesBaseScreen()
        layoutAuthHeader(titleLabel: registerTitle, subtitleLabel: subtitleLabel)

        let emailBottomAnchor = layoutFormField(
            label: emailLabel,
            textField: emailTextField,
            below: subtitleLabel.bottomAnchor,
            topSpacing: 82
        )

        let passwordBottomAnchor = layoutFormField(
            label: nil,
            textField: passwordTextField,
            below: emailBottomAnchor,
            topSpacing: 23
        )

        layoutFormField(
            label: nil,
            textField: confirmPasswordTextField,
            below: passwordBottomAnchor,
            topSpacing: 10
        )

        layoutBottomLink(loginButton)
        layoutPrimaryFooterButton(registerButton, above: loginButton.topAnchor)
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
                let email = try await viewModel.submitRegister()
                await MainActor.run { [weak self] in
                    self?.navDelegate?.onRegistrationCodeSent(email: email)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.showOkAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    @objc func onLoginTapped() {
        navDelegate?.onLoginTapped()
    }
    @objc private func onBackTapped() {
        navDelegate?.onLoginTapped()
    }
    
    @objc private func onEyeTapped(_ sender: UIButton) {
        let field: UITextField
        if sender.tag == 1 {
            field = passwordTextField
        } else {
            field = confirmPasswordTextField
        }

        field.toggleSecureEntryKeepingCursor(trigger: sender)
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
