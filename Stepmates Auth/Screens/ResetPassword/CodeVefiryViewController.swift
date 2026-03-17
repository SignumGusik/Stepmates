//
//  CodeVefiryViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 14/03/2026.
//

import UIKit

protocol CodeVerifyNavDelegate: AnyObject {
    func onBackFromCode()
    func onRegistrationVerified()
    func onPasswordResetCodeVerified(code: String)
}
final class CodeVerifyViewController: UIViewController {

    private lazy var titleLabel = UILabel.makeTitle(text: "Введите код")
    private lazy var subtitleLabel = UILabel.makeManrope(
        text: "Мы прислали вам код подтверждения на почту\n\(email)", style: Constants.manropeMedium, size: 14
    )

    private lazy var codeStack = UIStackView.makeCodeInputStack()
    private var codeFields: [UITextField] = []

    private lazy var timerLabel = UILabel.makeManrope(text: "Повторно отправить код через 1:00", style: Constants.manropeMedium, size: 14)

    private lazy var resendButton = UIButton.makeLinkButton(
        title: "Отправить код повторно",
        target: self,
        action: #selector(onResendTapped)
    )

    weak var navDelegate: CodeVerifyNavDelegate?

    private let email: String
    private let viewModel: ViewModel

    private var timer: Timer?
    private var secondsLeft: Int = 60

    required init(viewModel: ViewModel) {
        self.viewModel = viewModel
        self.email = viewModel.email
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupCodeFields()
        startCountdown(seconds: 60)
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - Setup
private extension CodeVerifyViewController {

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

        codeStack
            .addTo(view)
            .pinTop(toAnchor: subtitleLabel.bottomAnchor, constant: 70)
            .centerXOn(view)
            .setHeight(64)

        timerLabel
            .addTo(view)
            .pinTop(toAnchor: codeStack.bottomAnchor, constant: 25)
            .centerXOn(view)

        resendButton
            .addTo(view)
            .pinTop(toAnchor: codeStack.bottomAnchor, constant: 25)
            .centerXOn(view)

        // по умолчанию: сначала виден таймер, кнопка скрыта
        resendButton.isHidden = true
    }

    func setupCodeFields() {
        codeFields = (0..<6).map { idx in
            makeCodeField(tag: idx)
        }
        codeFields.forEach { codeStack.addArrangedSubview($0) }
        updateFocusUI(activeIndex: 0)
        codeFields.first?.becomeFirstResponder()
    }

    func makeCodeField(tag: Int) -> UITextField {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.tag = tag

        tf.keyboardType = .numberPad
        tf.textAlignment = .center
        tf.font = UIFont(name: "Manrope-Medium", size: 24)
        tf.backgroundColor = Constants.beige
        tf.layer.cornerRadius = 16
        tf.clipsToBounds = true
        tf.setSize(width: 48, height: 64)

        tf.layer.borderWidth = 0
        tf.layer.borderColor = UIColor.clear.cgColor

        tf.delegate = self
        tf.addTarget(self, action: #selector(onCodeChanged(_:)), for: .editingChanged)
        tf.textContentType = .oneTimeCode

        return tf
    }
}

// MARK: - Timer
private extension CodeVerifyViewController {

    func startCountdown(seconds: Int) {
        timer?.invalidate()

        secondsLeft = seconds
        timerLabel.isHidden = false
        resendButton.isHidden = true

        updateTimerLabel()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.secondsLeft -= 1
            self.updateTimerLabel()

            if self.secondsLeft <= 0 {
                self.timer?.invalidate()
                self.timer = nil
                self.timerLabel.isHidden = true
                self.resendButton.isHidden = false
            }
        }
    }

    func updateTimerLabel() {
        let m = max(secondsLeft, 0) / 60
        let s = max(secondsLeft, 0) % 60
        timerLabel.text = String(format: "Повторно отправить код через %d:%02d", m, s)
    }
}

private extension CodeVerifyViewController {
    func verifyAndGoNext(code: String) {
        codeFields.forEach { $0.isEnabled = false }

        Task { [weak self] in
            guard let self else { return }
            
            do {
                try await viewModel.verifyCode(code: code)
                
                await MainActor.run {
                    self.codeFields.forEach { $0.isEnabled = true }
                    
                    if self.viewModel.isRegistrationFlow {
                        self.showOkAlert(title: "Успешно", message: "Почта подтверждена") {
                            self.navDelegate?.onRegistrationVerified()
                        }
                    } else {
                        self.navDelegate?.onPasswordResetCodeVerified(code: code)
                    }
                }
            } catch {
                await MainActor.run {
                    self.codeFields.forEach { $0.isEnabled = true }
                    self.showOkAlert(title: "Неверный код", message: error.localizedDescription)
                    self.codeFields.forEach { $0.text = "" }
                    self.updateFocusUI(activeIndex: 0)
                    self.codeFields.first?.becomeFirstResponder()
                }
            }
        }
    }
}

// MARK: - Actions
private extension CodeVerifyViewController {

    @objc private func onResendTapped() {
        Task { [weak self] in
            guard let self else { return }
            
            do {
                try await viewModel.resendCode()
                
                await MainActor.run {
                    let message = self.viewModel.isRegistrationFlow
                        ? "Код подтверждения отправлен повторно"
                        : "Код для сброса пароля отправлен повторно"
                    
                    self.showOkAlert(title: "Успешно", message: message)
                }
            } catch {
                await MainActor.run {
                    self.showOkAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    @objc func onCodeChanged(_ sender: UITextField) {
        if let text = sender.text, text.count > 1 {
            sender.text = String(text.suffix(1))
        }

        updateFocusUI(activeIndex: sender.tag)

        if let text = sender.text, text.isEmpty == false {
            let nextIndex = sender.tag + 1
            if nextIndex < codeFields.count {
                updateFocusUI(activeIndex: nextIndex)
                codeFields[nextIndex].becomeFirstResponder()
            } else {
                let code = codeFields.compactMap { $0.text }.joined()
                if code.count == 6 {
                    view.endEditing(true)
                    verifyAndGoNext(code: code)
                }
            }
        }
    }

    func updateFocusUI(activeIndex: Int) {
        for (i, tf) in codeFields.enumerated() {
            if i == activeIndex {
                tf.layer.borderWidth = 1
                tf.layer.borderColor = Constants.purple?.cgColor
            } else {
                tf.layer.borderWidth = 0
                tf.layer.borderColor = UIColor.clear.cgColor
            }
        }
    }
}

// MARK: - UITextFieldDelegate
extension CodeVerifyViewController: UITextFieldDelegate {

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {

        if string.isEmpty {
            if (textField.text ?? "").isEmpty {
                let prevIndex = textField.tag - 1
                if prevIndex >= 0 {
                    codeFields[prevIndex].text = ""
                    updateFocusUI(activeIndex: prevIndex)
                    codeFields[prevIndex].becomeFirstResponder()
                }
            } else {
                textField.text = ""
            }
            return false
        }

        return CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: string))
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        updateFocusUI(activeIndex: textField.tag)
    }
}

