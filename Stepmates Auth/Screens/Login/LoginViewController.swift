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
    private var slowLoginWorkItem: DispatchWorkItem?

    required init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }

    deinit {
        slowLoginWorkItem?.cancel()
    }
}

// MARK: - Lifecycle
extension LoginViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        passwordTextField.attachPasswordVisibilityToggle(
            target: self,
            action: #selector(onEyeTapped(_:)),
            tag: 1
        )
    }
}

// MARK: - View Setup
private extension LoginViewController {
    func setupViews() {
        applyStepmatesBaseScreen()
        layoutAuthHeader(titleLabel: titleLabel, subtitleLabel: subtitleLabel)

        let emailBottomAnchor = layoutFormField(
            label: emailLabel,
            textField: emailTextField,
            below: subtitleLabel.bottomAnchor,
            topSpacing: 82
        )

        layoutFormField(
            label: passwordLabel,
            textField: passwordTextField,
            below: emailBottomAnchor,
            topSpacing: 23
        )

        forgotPasswordButton
            .addTo(view)
            .pinTop(toAnchor: passwordTextField.bottomAnchor, constant: 10)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -Constants.sideInset)

        layoutBottomLink(registerButton)
        layoutPrimaryFooterButton(submitButton, above: registerButton.topAnchor)
    }
}

// MARK: - Actions
private extension LoginViewController {

    @objc func onSubmitTapped() {
        viewModel.email = emailTextField.text
        viewModel.password = passwordTextField.text

        setSubmitting(true)

        Task {
            do {
                try await viewModel.submitLogin()
                await MainActor.run { [weak self] in
                    self?.setSubmitting(false)
                    self?.navDelegate?.onLoginSuccessfull()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.setSubmitting(false)
                    self?.showOkAlert(title: "Не удалось войти", message: error.localizedDescription)
                }
            }
        }
    }

    func setSubmitting(_ isSubmitting: Bool) {
        slowLoginWorkItem?.cancel()
        slowLoginWorkItem = nil

        submitButton.isEnabled = isSubmitting == false
        submitButton.alpha = isSubmitting ? 0.72 : 1
        submitButton.setTitle(isSubmitting ? "Входим..." : "Бежать дальше", for: .normal)

        guard isSubmitting else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.submitButton.setTitle("Сервер просыпается...", for: .normal)
        }

        slowLoginWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: workItem)
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
        passwordTextField.toggleSecureEntryKeepingCursor(trigger: sender)
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
