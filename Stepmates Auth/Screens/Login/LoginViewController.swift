//
//  LoginViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 23/01/2026.
//

import UIKit

protocol LoginNavDelegate: AnyObject {
    func onRegisterTapped()
    func onLoginSuccessfull()
    func onForgotPassword()
}

final class LoginViewController: UIViewController {

    private lazy var backButton = UIButton.makeBackButton(
        target: self,
        action: #selector(onBackTapped)
    )

    private lazy var titleLabel = UILabel.makeTitle(text: "Войти")
    private lazy var subtitleLabel = UILabel.makeManrope(text: "Войдите, чтобы ходить с друзьями", style: Constants.manropeMedium, size: 14)
    private lazy var emailLabel = UILabel.makeManrope(text: "Почта:", style: Constants.manropeMedium, size: 16)
    private lazy var passwordLabel = UILabel.makeManrope(text: "Пароль:", style: Constants.manropeMedium, size: 16)

    private lazy var emailTextField = UITextField.makeEmailField(delegate: self)
    private lazy var passwordTextField =  UITextField.makePasswordField(placeholder: "Введите пароль:", delegate: self)

    private lazy var forgotPasswordButton = UIButton.makeLinkButton(
        title: "Забыли пароль?",
        target: self,
        action: #selector(onForgotPasswordTapped)
    )

    private lazy var submitButton = UIButton.makePrimaryBigButton(
        title: "Бежать дальше",
        target: self,
        action: #selector(onSubmitTapped)
    )

    private lazy var registerButton = UIButton.makeLinkButton(
        title: "Ещё нет аккаунта? Создайте",
        target: self,
        action: #selector(onRegisterTapped)
    )

    weak var navDelegate: LoginNavDelegate?
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
extension LoginViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backButtonTitle = ""
        setupViews()
        attachEyeButton(to: passwordTextField, tag: 1)
    }
}

// MARK: - View Setup
private extension LoginViewController {
    func setupViews() {
        view.backgroundColor = .white

        titleLabel
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: Constants.titleTop)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailingLessThanOrEqual(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)

        subtitleLabel
            .addTo(view)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 10)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailingLessThanOrEqual(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)

        emailLabel
            .addTo(view)
            .pinTop(toAnchor: subtitleLabel.bottomAnchor, constant: 82)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)

        emailTextField
            .addTo(view)
            .pinTop(toAnchor: emailLabel.bottomAnchor, constant: 11)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailing(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)
            .setHeight(50)

        passwordLabel
            .addTo(view)
            .pinTop(toAnchor: emailTextField.bottomAnchor, constant: 23)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)

        passwordTextField
            .addTo(view)
            .pinTop(toAnchor: passwordLabel.bottomAnchor, constant: 11)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailing(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)
            .setHeight(50)

        // "Забыли пароль?" — справа под полем пароля
        forgotPasswordButton
            .addTo(view)
            .pinTop(toAnchor: passwordTextField.bottomAnchor, constant: 10)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -Constants.sideInset)

        // Нижняя ссылка
        registerButton
            .addTo(view)
            .centerXOn(view)
            .pinBottom(toAnchor: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)

        // Большая кнопка над ссылкой
        submitButton
            .addTo(view)
            .pinBottom(toAnchor: registerButton.topAnchor, constant: -25)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailing(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)
            .setHeight(86)
    }

    func attachEyeButton(to textField: UITextField, tag: Int) {
        let button = UIButton(type: .system)
        button.tag = tag
        button.tintColor = .black
        button.setImage(UIImage(named: "eye_closed"), for: .normal)
        button.backgroundColor = .clear
        button.imageView?.contentMode = .scaleAspectFit
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
private extension LoginViewController {

    @objc func onSubmitTapped() {
        viewModel.email = emailTextField.text
        viewModel.password = passwordTextField.text

        Task {
            do {
                try await viewModel.submitLogin()
                await MainActor.run { [weak self] in
                    self?.navDelegate?.onLoginSuccessfull()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.showOkAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    @objc func onRegisterTapped() {
        navDelegate?.onRegisterTapped()
    }

    @objc func onForgotPasswordTapped() {
        navDelegate?.onForgotPassword()
    }

    @objc func onBackTapped() {
        // если Login у тебя root — можешь просто ничего не делать или закрывать модалку
        navigationController?.popViewController(animated: true)
    }

    @objc func onEyeTapped(_ sender: UIButton) {
        let wasFirstResponder = passwordTextField.isFirstResponder
        let currentText = passwordTextField.text

        passwordTextField.isSecureTextEntry.toggle()
        let imageName = passwordTextField.isSecureTextEntry ? "eye_closed" : "eye"
        sender.setImage(UIImage(named: imageName), for: .normal)

        // фикс для secureTextEntry (чтобы курсор не прыгал/текст не пропадал)
        passwordTextField.text = nil
        passwordTextField.text = currentText

        if wasFirstResponder {
            passwordTextField.becomeFirstResponder()
        }
    }
}

// MARK: - UITextFieldDelegate
extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailTextField {
            passwordTextField.becomeFirstResponder()
        } else {
            view.endEditing(true)
        }
        return false
    }
}


