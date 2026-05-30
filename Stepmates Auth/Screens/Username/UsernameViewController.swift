//
//  UsernameViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 17/03/2026.
//

import UIKit

protocol UsernameNavDelegate: AnyObject {
    func onUsernameSubmitted(username: String)
}

final class UsernameViewController: UIViewController {
    private lazy var titleLabel = UILabel.makeTitle(text: "Придумайте никнейм")
    private lazy var subtitleLabel = UILabel.makeManrope(
        text: "Он должен быть уникальным",
        style: Constants.manropeMedium,
        size: 14
    )

    private lazy var usernameLabel = UILabel.makeManrope(
        text: "Никнейм:",
        style: Constants.manropeMedium,
        size: 16
    )

    private lazy var usernameTextField = UITextField.makeEmailField(placeholder: "До 10 символов", delegate: self)

    private lazy var submitButton = UIButton.makePrimaryBigButton(
        title: "Бежать дальше",
        target: self,
        action: #selector(onSubmitTapped)
    )

    weak var navDelegate: UsernameNavDelegate?
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
private extension UsernameViewController {

    func setupViews() {
        applyStepmatesBaseScreen()
        layoutAuthHeader(titleLabel: titleLabel, subtitleLabel: subtitleLabel)
        layoutFormField(
            label: usernameLabel,
            textField: usernameTextField,
            below: subtitleLabel.bottomAnchor,
            topSpacing: 32
        )
        layoutPrimaryFooterButton(submitButton)
    }
}

// MARK: - Actions
private extension UsernameViewController {

    @objc func onSubmitTapped() {
        viewModel.username = usernameTextField.text

        Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await viewModel.submitUsername()
                await MainActor.run {
                    self.navDelegate?.onUsernameSubmitted(username: response.username)
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
extension UsernameViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }
}
