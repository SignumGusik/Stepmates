//
//  HomeGoalEditorView.swift
//  Stepmates Auth
//
//  Created by Codex on 30/05/2026.
//

import UIKit

final class HomeGoalEditorView: UIView {
    var onClose: (() -> Void)?
    var onTextChanged: (() -> Void)?
    var onQuickGoal: ((Int) -> Void)?
    var onSave: (() -> Void)?

    private let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
    private let blurView = UIVisualEffectView(effect: nil)
    private let dimControl = UIControl()
    private let cardView = UIView()
    private lazy var closeButton = UIButton.makeImageButton(
        imageName: "cancelBtn",
        target: self,
        action: #selector(onCloseTapped)
    )
    private let titleLabel = UILabel.makeManrope(
        text: "Введите цель",
        style: Constants.manropeExtraBold,
        size: 20,
        color: Constants.blue ?? .systemBlue
    )
    private let hintLabel = UILabel.makeManrope(
        text: Self.defaultHint,
        style: Constants.manropeMedium,
        size: 12,
        color: UIColor.black.withAlphaComponent(0.45)
    )
    private let textField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.backgroundColor = Constants.lightPurple
        field.layer.cornerRadius = 18
        field.clipsToBounds = true
        field.keyboardType = .numberPad
        field.textAlignment = .center
        field.textColor = Constants.blue ?? .systemBlue
        field.font = UIFont(name: Constants.manropeExtraBold, size: 28)
            ?? .systemFont(ofSize: 28, weight: .heavy)
        return field
    }()
    private lazy var saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Сохранить", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: Constants.manropeExtraBold, size: 16)
            ?? .systemFont(ofSize: 16, weight: .heavy)
        button.backgroundColor = Constants.orange ?? .orange
        button.layer.cornerRadius = 22
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(onSaveTapped), for: .touchUpInside)
        return button
    }()

    private static let defaultHint = "От 1 000 до 100 000 шагов"

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) not used")
    }

    func attach(to parentView: UIView) {
        addTo(parentView)
            .pinEdges(to: parentView)
    }

    func show(currentGoal: Int) {
        textField.text = "\(currentGoal)"
        resetControls()

        isHidden = false
        superview?.bringSubviewToFront(self)
        alpha = 0
        blurView.effect = nil
        cardView.alpha = 0
        cardView.transform = CGAffineTransform(translationX: 0, y: 22)
            .scaledBy(x: 0.96, y: 0.96)

        UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseOut]) {
            self.alpha = 1
            self.blurView.effect = self.blurEffect
        }

        UIView.animate(
            withDuration: 0.42,
            delay: 0,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.65,
            options: [.curveEaseOut]
        ) {
            self.cardView.alpha = 1
            self.cardView.transform = .identity
        } completion: { _ in
            self.textField.becomeFirstResponder()
        }
    }

    func hide() {
        endEditing(true)

        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseIn]) {
            self.alpha = 0
            self.blurView.effect = nil
            self.cardView.alpha = 0
            self.cardView.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        } completion: { _ in
            self.isHidden = true
            self.cardView.transform = .identity
        }
    }

    func parsedGoal() -> Int? {
        let digits = (textField.text ?? "").filter { $0.isNumber }
        guard let value = Int(digits),
              (1000...100000).contains(value) else {
            return nil
        }

        return value
    }

    @discardableResult
    func validateInput() -> Bool {
        let isValid = parsedGoal() != nil
        saveButton.isEnabled = isValid
        saveButton.alpha = isValid ? 1 : 0.55

        if isValid {
            setHint(Self.defaultHint, color: UIColor.black.withAlphaComponent(0.45))
        } else {
            setHint("Введите число от 1 000 до 100 000", color: Constants.orange ?? .orange)
        }

        return isValid
    }

    func setSaving(_ isSaving: Bool) {
        saveButton.isEnabled = !isSaving
        saveButton.alpha = isSaving ? 0.7 : 1
        saveButton.setTitle(isSaving ? "Сохраняем..." : "Сохранить", for: .normal)
    }

    func showSaveError() {
        setSaving(false)
        setHint("Не удалось сохранить цель", color: Constants.orange ?? .orange)
    }
}

private extension HomeGoalEditorView {
    func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        isHidden = true
        alpha = 0

        blurView.addTo(self)
            .pinEdges(to: self)

        dimControl.translatesAutoresizingMaskIntoConstraints = false
        dimControl.backgroundColor = UIColor.black.withAlphaComponent(0.10)
        dimControl.addTarget(self, action: #selector(onCloseTapped), for: .touchUpInside)
        dimControl.addTo(self)
            .pinEdges(to: self)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.applyFloatingCardStyle(
            backgroundColor: .white,
            cornerRadius: 22,
            shadowOpacity: 0.14,
            shadowRadius: 18,
            shadowYOffset: 10
        )
        cardView.layer.borderWidth = 2
        cardView.layer.borderColor = (Constants.blue ?? .systemBlue).cgColor

        cardView.addTo(self)
            .centerXOn(self)
            .centerYOn(self)
            .setWidth(320)
            .setHeight(270)

        closeButton.addTo(cardView)
            .pinTop(toAnchor: cardView.topAnchor, constant: 14)
            .pinRight(toAnchor: cardView.rightAnchor, constant: -14)
            .setSize(width: 24, height: 24)

        titleLabel.addTo(cardView)
            .pinTop(toAnchor: cardView.topAnchor, constant: 20)
            .pinLeft(toAnchor: cardView.leftAnchor, constant: 22)
            .pinRight(toAnchor: closeButton.leftAnchor, constant: -10)

        textField.addTo(cardView)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: 18)
            .pinLeft(toAnchor: cardView.leftAnchor, constant: 22)
            .pinRight(toAnchor: cardView.rightAnchor, constant: -22)
            .setHeight(58)
        textField.addTarget(self, action: #selector(onTextFieldChanged), for: .editingChanged)

        hintLabel.addTo(cardView)
            .pinTop(toAnchor: textField.bottomAnchor, constant: 8)
            .centerXOn(cardView)

        let quickStack = makeQuickGoalStack()
        quickStack.addTo(cardView)
            .pinTop(toAnchor: hintLabel.bottomAnchor, constant: 16)
            .pinLeft(toAnchor: cardView.leftAnchor, constant: 22)
            .pinRight(toAnchor: cardView.rightAnchor, constant: -22)
            .setHeight(36)

        saveButton.addTo(cardView)
            .pinTop(toAnchor: quickStack.bottomAnchor, constant: 18)
            .pinLeft(toAnchor: cardView.leftAnchor, constant: 22)
            .pinRight(toAnchor: cardView.rightAnchor, constant: -22)
            .setHeight(46)
    }

    func makeQuickGoalStack() -> UIStackView {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually

        for value in [8000, 10000, 12000] {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.tag = value
            button.setTitle(formatSteps(value), for: .normal)
            button.setTitleColor(Constants.blue ?? .systemBlue, for: .normal)
            button.titleLabel?.font = UIFont(name: Constants.manropeExtraBold, size: 13)
                ?? .systemFont(ofSize: 13, weight: .heavy)
            button.backgroundColor = Constants.lightPurple
            button.layer.cornerRadius = 12
            button.clipsToBounds = true
            button.addTarget(self, action: #selector(onQuickGoalTapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        return stack
    }

    func resetControls() {
        setHint(Self.defaultHint, color: UIColor.black.withAlphaComponent(0.45))
        setSaving(false)
        saveButton.isEnabled = true
    }

    func setHint(_ text: String, color: UIColor) {
        hintLabel.text = text
        hintLabel.textColor = color
    }

    func formatSteps(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    @objc func onCloseTapped() {
        onClose?()
    }

    @objc func onTextFieldChanged() {
        onTextChanged?()
    }

    @objc func onQuickGoalTapped(_ sender: UIButton) {
        textField.text = "\(sender.tag)"
        onQuickGoal?(sender.tag)
    }

    @objc func onSaveTapped() {
        onSave?()
    }
}
