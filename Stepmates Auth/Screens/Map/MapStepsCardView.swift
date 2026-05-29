//
//  MapStepsCardView.swift
//  Stepmates Auth
//
//  Created by Диана on 09/05/2026.
//


import UIKit

final class MapStepsCardView: UIView {

    var onRankingTap: (() -> Void)?
    var onCollapseChanged: ((Bool) -> Void)?

    private let collapseHandleButton = UIButton(type: .system)
    private let stepsValueLabel = UILabel()
    private let rankingButton = UIButton(type: .system)

    private var bottomConstraint: NSLayoutConstraint?
    private var isCollapsed = false
    private var previousPlace: Int?
    private var localStepsOverride: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupGestures()
    }

    func attach(to parentView: UIView) {
        parentView.addSubview(self)

        bottomConstraint = bottomAnchor.constraint(
            equalTo: parentView.safeAreaLayoutGuide.bottomAnchor,
            constant: -16
        )

        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 22),
            trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -22),
            heightAnchor.constraint(equalToConstant: 128),
            bottomConstraint!
        ])
    }

    func applyRanking(_ ranking: MapRankingDTO) {
        applyStepsText(steps: localStepsOverride ?? ranking.steps, goal: 10_000)

        let placeText: String
        if let myPlace = ranking.myPlace {
            placeText = "\(myPlace) / \(ranking.total)"
        } else {
            placeText = "— / \(ranking.total)"
        }

        applyRankingText(placeText: placeText)

        if let previousPlace,
           let myPlace = ranking.myPlace,
           previousPlace > myPlace {
            animateRankRise()
        }

        previousPlace = ranking.myPlace
    }

    func applyLocalSteps(_ steps: Int, goal: Int = 10_000) {
        localStepsOverride = max(0, steps)
        applyStepsText(steps: max(0, steps), goal: goal)
    }
}

private extension MapStepsCardView {

    func applyStepsText(steps: Int, goal: Int) {

        let fullText = NSMutableAttributedString(
            string: "\(steps.formattedWithSpaces)",
            attributes: [
                .font: UIFont(name: Constants.manropeExtraBold, size: 40)
                    ?? UIFont.systemFont(ofSize: 40, weight: .black),
                .foregroundColor: UIColor.black
            ]
        )

        fullText.append(
            NSAttributedString(
                string: " / \(goal.formattedWithSpaces)",
                attributes: [
                    .font: UIFont(name: Constants.manropeExtraBold, size: 40)
                        ?? UIFont.systemFont(ofSize: 40, weight: .black),
                    .foregroundColor: Constants.grey ?? UIColor.systemGray3
                ]
            )
        )

        stepsValueLabel.attributedText = fullText
    }

    func applyRankingText(placeText: String) {
        let rankingText = NSMutableAttributedString(
            string: "Рейтинг на сегодня: ",
            attributes: [
                .font: UIFont(name: Constants.manropeMedium, size: 16)
                    ?? UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor.black
            ]
        )

        rankingText.append(
            NSAttributedString(
                string: "\(placeText) ›",
                attributes: [
                    .font: UIFont(name: Constants.manropeMedium, size: 16)
                        ?? UIFont.systemFont(ofSize: 16, weight: .medium),
                    .foregroundColor: Constants.purple ?? UIColor.systemBlue
                ]
            )
        )

        rankingButton.setAttributedTitle(rankingText, for: .normal)
    }

    func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        backgroundColor = UIColor.white.withAlphaComponent(0.96)
        layer.cornerRadius = 24
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.13
        layer.shadowRadius = 18
        layer.shadowOffset = CGSize(width: 0, height: 8)

        collapseHandleButton.translatesAutoresizingMaskIntoConstraints = false
        collapseHandleButton.setTitle("⌄", for: .normal)
        collapseHandleButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        collapseHandleButton.tintColor = UIColor.darkGray.withAlphaComponent(0.38)
        collapseHandleButton.backgroundColor = .clear
        collapseHandleButton.layer.cornerRadius = 0
        collapseHandleButton.layer.shadowOpacity = 0
        collapseHandleButton.addTarget(self, action: #selector(onToggleStepsCard), for: .touchUpInside)

        stepsValueLabel.translatesAutoresizingMaskIntoConstraints = false
        stepsValueLabel.textColor = .black
        stepsValueLabel.text = "0 / 10 000"
        stepsValueLabel.adjustsFontSizeToFitWidth = true
        stepsValueLabel.minimumScaleFactor = 0.8

        rankingButton.translatesAutoresizingMaskIntoConstraints = false
        rankingButton.contentHorizontalAlignment = .leading
        rankingButton.addTarget(self, action: #selector(onRankingButtonTapped), for: .touchUpInside)

        addSubview(collapseHandleButton)
        addSubview(stepsValueLabel)
        addSubview(rankingButton)

        NSLayoutConstraint.activate([
            collapseHandleButton.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            collapseHandleButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            collapseHandleButton.widthAnchor.constraint(equalToConstant: 58),
            collapseHandleButton.heightAnchor.constraint(equalToConstant: 28),

            stepsValueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 26),
            stepsValueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -26),
            stepsValueLabel.topAnchor.constraint(equalTo: topAnchor, constant: 34),
            rankingButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 26),
            rankingButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -26),
            rankingButton.topAnchor.constraint(equalTo: stepsValueLabel.bottomAnchor, constant: 8),
            rankingButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    func setupGestures() {
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(onSwipeDown))
        swipeDown.direction = .down
        addGestureRecognizer(swipeDown)

        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(onSwipeUp))
        swipeUp.direction = .up
        addGestureRecognizer(swipeUp)
    }

    func setCollapsed(_ collapsed: Bool) {
        guard isCollapsed != collapsed else { return }

        isCollapsed = collapsed
        bottomConstraint?.constant = isCollapsed ? 96 : -16
        onCollapseChanged?(isCollapsed)

        UIView.animate(
            withDuration: 0.32,
            delay: 0,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut]
        ) {
            self.collapseHandleButton.transform = self.isCollapsed
                ? CGAffineTransform(rotationAngle: .pi)
                : .identity

            self.alpha = self.isCollapsed ? 0.92 : 1
            self.superview?.layoutIfNeeded()
        }
    }

    @objc func onToggleStepsCard() {
        setCollapsed(!isCollapsed)
    }

    @objc func onSwipeDown() {
        setCollapsed(true)
    }

    @objc func onSwipeUp() {
        setCollapsed(false)
    }

    @objc func onRankingButtonTapped() {
        onRankingTap?()
    }

    func animateRankRise() {
        rankingButton.transform = CGAffineTransform(translationX: 0, y: 7)
        rankingButton.alpha = 0.72

        UIView.animate(
            withDuration: 0.26,
            delay: 0,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.65,
            options: [.curveEaseOut, .beginFromCurrentState]
        ) {
            self.rankingButton.transform = .identity
            self.rankingButton.alpha = 1
        }
    }
}

private extension Int {
    var formattedWithSpaces: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
