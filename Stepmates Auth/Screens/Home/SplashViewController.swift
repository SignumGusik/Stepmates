//
//  SplashViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 19/05/2026.
//


import UIKit

protocol SplashNavDelegate: AnyObject {
    func onSplashFinished()
}

final class SplashViewController: UIViewController {

    weak var navDelegate: SplashNavDelegate?

    private let starsView = StarsBackgroundView()

    private lazy var titleLabel = UILabel.makeManrope(
        text: "Stepmates",
        style: Constants.manropeExtraBold,
        size: 46,
        color: .white
    )

    private lazy var subtitleLabel = UILabel.makeManrope(
        text: "гуляй с друзьями",
        style: Constants.manropeMedium,
        size: 18,
        color: UIColor.white.withAlphaComponent(0.82)
    )

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        return stack
    }()

    private let glowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        view.layer.cornerRadius = 90
        view.clipsToBounds = true
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavBar()
        setupViews()
        startAnimation()
    }

    private func setupNavBar() {
        navigationItem.backButtonDisplayMode = .minimal

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()

        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.clear
        ]

        appearance.backButtonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.clear
        ]
        appearance.backButtonAppearance.highlighted.titleTextAttributes = [
            .foregroundColor: UIColor.clear
        ]

        let navBar = navigationController?.navigationBar
        navBar?.isTranslucent = true
        navBar?.setBackgroundImage(UIImage(), for: .default)
        navBar?.shadowImage = UIImage()
        navBar?.backgroundColor = .clear

        navBar?.standardAppearance = appearance
        navBar?.scrollEdgeAppearance = appearance
        navBar?.compactAppearance = appearance
        navBar?.tintColor = .clear
    }
}

// MARK: - Setup
private extension SplashViewController {

    func setupViews() {
        view.backgroundColor = Constants.blue ?? .systemBlue

        starsView.translatesAutoresizingMaskIntoConstraints = false
        starsView
            .addTo(view)
            .pinEdges(to: view)

        view.sendSubviewToBack(starsView)

        glowView
            .addTo(view)
            .centerXOn(view)
            .centerYOn(view)
            .setSize(width: 180, height: 180)

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)

        contentStack
            .addTo(view)
            .centerXOn(view)
            .centerYOn(view)

        titleLabel.textAlignment = .center
        subtitleLabel.textAlignment = .center

        contentStack.alpha = 0
        contentStack.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        glowView.alpha = 0
        glowView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
    }

    func startAnimation() {
        UIView.animate(
            withDuration: 0.55,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            self.contentStack.alpha = 1
            self.contentStack.transform = .identity
            self.glowView.alpha = 1
            self.glowView.transform = .identity
        }

        UIView.animate(
            withDuration: 1.4,
            delay: 0,
            options: [.curveEaseInOut, .autoreverse, .repeat]
        ) {
            self.glowView.alpha = 0.35
            self.glowView.transform = CGAffineTransform(scaleX: 1.18, y: 1.18)
        }
        UIView.animate(
            withDuration: 1.1,
            delay: 0,
            options: [.curveEaseInOut]
        ) {
            self.starsView.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) { [weak self] in
            self?.finishSplash()
        }
    }

    func finishSplash() {
        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            options: [.curveEaseInOut]
        ) {
            self.contentStack.alpha = 0
            self.contentStack.transform = CGAffineTransform(scaleX: 1.04, y: 1.04)
        } completion: { [weak self] _ in
            self?.navDelegate?.onSplashFinished()
        }
    }
}
