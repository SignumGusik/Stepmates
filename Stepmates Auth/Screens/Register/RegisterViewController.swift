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
        navigationItem.backButtonTitle = ""
        setupViews()
        attachEyeButton(to: passwordTextField, tag: 1)
        attachEyeButton(to: confirmPasswordTextField, tag: 2)
        
    }
    
    
    
    
}
// MARK: - View Setup/Registration
extension RegisterViewController {
    
    func setupViews() {
        view.backgroundColor = .white

        // Title
        registerTitle
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: Constants.titleTop)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailingLessThanOrEqual(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)

        subtitleLabel
            .addTo(view)
            .setSize(width: Constants.subtitleWidth, height: Constants.subtitleHeight)
            .pinTop(toAnchor: registerTitle.bottomAnchor, constant: 10)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: Constants.subtitleLeft)

        emailLabel
            .addTo(view)
            .setSize(width: Constants.emailLabelWidth, height: Constants.emailLabelHeight)
            .pinTop(toAnchor: subtitleLabel.bottomAnchor, constant: 82)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: Constants.emailLabelLeft)

        // Email field
        emailTextField
            .addTo(view)
            .pinTop(toAnchor: emailLabel.bottomAnchor, constant: 11)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailing(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)
            .setHeight(50)

        // Password field
        passwordTextField
            .addTo(view)
            .pinTop(toAnchor: emailTextField.bottomAnchor, constant: 23)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailing(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)
            .setHeight(50)

        // Confirm password field
        confirmPasswordTextField
            .addTo(view)
            .pinTop(toAnchor: passwordTextField.bottomAnchor, constant: 10)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailing(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)
            .setHeight(50)

        // Bottom login
        loginButton
            .addTo(view)
            .centerXOn(view)
            .pinBottom(toAnchor: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        
    
        registerButton
            .addTo(view)
            .pinBottom(toAnchor: loginButton.topAnchor, constant: -25)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailing(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)
            .setHeight(86)
    }
    
    private func attachEyeButton(to textField: UITextField, tag: Int) {
        let button = UIButton(type: .system)
        button.tag = tag
        button.tintColor = .black
        button.setImage(UIImage(named: "eye_closed"), for: .normal)
        button.setTitle(nil, for: .normal)
        button.backgroundColor = .clear
        button.imageView?.contentMode = .scaleAspectFit
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        button.addTarget(self, action: #selector(onEyeTapped(_:)), for: .touchUpInside)
        let containerWidth: CGFloat = 60
        let containerHeight: CGFloat = 44
        let container = UIView(frame: CGRect(x: 0, y: 0, width: containerWidth, height: containerHeight))
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        let shiftLeft: CGFloat = 8
        button.center = CGPoint(x: containerWidth / 2 - shiftLeft, y: containerHeight / 2)

        container.addSubview(button)

        textField.rightView = container
        textField.rightViewMode = .always
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

        let wasFirstResponder = field.isFirstResponder
        let currentText = field.text
        field.isSecureTextEntry.toggle()
        let imageName = field.isSecureTextEntry ? "eye_closed" : "eye"
        sender.setImage(UIImage(named: imageName), for: .normal)
        field.text = nil
        field.text = currentText

        if wasFirstResponder {
            field.becomeFirstResponder()
        }
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
