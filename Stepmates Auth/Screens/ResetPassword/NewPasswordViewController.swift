//
//  NewPasswordViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 15/03/2026.
//

import UIKit

protocol NewPasswordNavDelegate: AnyObject {
    func onPasswordChangedSuccessfully()
    func onBackFromNewPassword()
}

final class NewPasswordViewController: UIViewController {
    private lazy var titleLabel = UILabel.makeTitle(text: "Измените пароль")
    private lazy var subtitleLabel = UILabel.makeManrope(text: "Пароль должен быть надёжным", style: Constants.manropeMedium, size: 14)

    private lazy var passwordTextField = UITextField.makePasswordField(
        placeholder: "Придумайте пароль:",
        delegate: self
    )

    private lazy var confirmPasswordTextField = UITextField.makePasswordField(
        placeholder: "Повторите пароль:",
        delegate: self
    )

    private lazy var submitButton = UIButton.makePrimaryBigButton(
        title: "Бежать дальше",
        target: self,
        action: #selector(onSubmitTapped)
    )

    weak var navDelegate: NewPasswordNavDelegate?

    private let viewModel: ViewModel

    required init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }

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

// MARK: - View Setup
private extension NewPasswordViewController {

    func setupViews() {
        applyStepmatesBaseScreen()
        layoutAuthHeader(titleLabel: titleLabel, subtitleLabel: subtitleLabel)

        let passwordBottomAnchor = layoutFormField(
            label: nil,
            textField: passwordTextField,
            below: subtitleLabel.bottomAnchor,
            topSpacing: 32
        )

        layoutFormField(
            label: nil,
            textField: confirmPasswordTextField,
            below: passwordBottomAnchor,
            topSpacing: 10
        )

        layoutPrimaryFooterButton(submitButton)
    }
}

// MARK: - Actions
private extension NewPasswordViewController {

    @objc func onBackTapped() {
        navDelegate?.onBackFromNewPassword()
    }

    @objc func onSubmitTapped() {
        viewModel.password = passwordTextField.text
        viewModel.confirmPassword = confirmPasswordTextField.text

        submitButton.isEnabled = false

        Task { [weak self] in
            guard let self else { return }
            do {
                try await viewModel.submitNewPassword()
                await MainActor.run {
                    self.submitButton.isEnabled = true
                    self.showOkAlert(title: "Успех", message: "Пароль изменён") {
                        self.navDelegate?.onPasswordChangedSuccessfully()
                    }
                }
            } catch {
                await MainActor.run {
                    self.submitButton.isEnabled = true
                    self.showOkAlert(title: "Ошибка", message: self.serverMessage(from: error))
                }
            }
        }
    }

    @objc func onEyeTapped(_ sender: UIButton) {
        let field: UITextField = (sender.tag == 1) ? passwordTextField : confirmPasswordTextField
        field.toggleSecureEntryKeepingCursor(trigger: sender)
    }

    func serverMessage(from error: Error) -> String {
        if case let NetworkError.failedStatusCodeResponseData(_, data) = error,
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return error.localizedDescription
    }
}

// MARK: - UITextFieldDelegate
extension NewPasswordViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == passwordTextField {
            confirmPasswordTextField.becomeFirstResponder()
        } else {
            view.endEditing(true)
        }
        return false
    }
}

// MARK: - ViewModel
extension NewPasswordViewController {
    final class ViewModel {
        var password: String?
        var confirmPassword: String?

        private let email: String
        private let code: String
        private let networkHandler: NetworkHandler

        init(email: String, code: String, networkHandler: NetworkHandler) {
            self.email = email
            self.code = code
            self.networkHandler = networkHandler
        }
    }
}

extension NewPasswordViewController.ViewModel {

    func submitNewPassword() async throws {
        guard let password, let confirmPassword else { throw FormError.missingFields }

        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard p.isEmpty == false, c.isEmpty == false else { throw FormError.missingFields }
        guard p == c else { throw FormError.passwordsDoNotMatch }

        let route = NetworkRoutes.passwordResetConfirm
        guard let url = route.url else { throw ConfigurationError.nilObject }

        let body: [String: Any] = [
            "email": email,
            "code": code,
            "password": p,
            "password2": c
        ]

        _ = try await networkHandler.request(
            url,
            jsonDictionary: body,
            httpMethod: route.method.rawValue
        )
    }
}
