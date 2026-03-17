//
//  ResetPasswordViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 14/03/2026.
//

import UIKit

protocol ResetPasswordNavDelegate: AnyObject {
    func onResetPasswordSubmitted(email: String)
}

final class ResetPasswordViewController: UIViewController {
    private lazy var titleLabel = UILabel.makeTitle(text: "Восстановить пароль")
    private lazy var subtitleLabel = UILabel.makeManrope(text:
                                                                    "Введите почту от аккаунта, мы пришлём код подтверждения", style: Constants.manropeMedium, size: 14
    )

    private lazy var emailLabel = UILabel.makeManrope(text: "Почта:", style: Constants.manropeMedium, size: 16)
    private lazy var emailTextField = UITextField.makeEmailField(delegate: self)

    private lazy var submitButton = UIButton.makePrimaryBigButton(
        title: "Восстановить доступ",
        target: self,
        action: #selector(onSubmitTapped)
    )

    weak var navDelegate: ResetPasswordNavDelegate?
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
    }
}

// MARK: - View Setup
private extension ResetPasswordViewController {

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
            .pinTrailing(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)

        emailLabel
            .addTo(view)
            .pinTop(toAnchor: subtitleLabel.bottomAnchor, constant: 32)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)

        emailTextField
            .addTo(view)
            .pinTop(toAnchor: emailLabel.bottomAnchor, constant: 11)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailing(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)
            .setHeight(50)

        submitButton
            .addTo(view)
            .pinBottom(toAnchor: view.safeAreaLayoutGuide.bottomAnchor, constant: -28)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailing(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)
            .setHeight(86)
    }
}

// MARK: - Actions
private extension ResetPasswordViewController {

    @objc func onBackTapped() {
    }

    @objc func onSubmitTapped() {
        viewModel.email = emailTextField.text

        Task { [weak self] in
            guard let self else { return }
            do {
                try await viewModel.submitReset()
                let email = (self.emailTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    self.navDelegate?.onResetPasswordSubmitted(email: email)
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(title: "Ошибка", message: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - UITextFieldDelegate
extension ResetPasswordViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }
}
