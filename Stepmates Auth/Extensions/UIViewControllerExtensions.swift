//
//  UIViewControllerExtensions.swift
//  Stepmates Auth
//
//  Created by Диана on 24/01/2026.
//

import UIKit

extension UIViewController {
    
    func showOkAlert(title: String?, message: String? = nil, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .cancel) { _ in completion?() }
        alert.addAction(okAction)
        present(alert, animated: true)
    }

    func applyStepmatesBaseScreen(backgroundColor: UIColor = .white) {
        view.backgroundColor = backgroundColor
        navigationItem.backButtonTitle = ""
    }

    func layoutAuthHeader(
        titleLabel: UILabel,
        subtitleLabel: UILabel?,
        top: CGFloat = Constants.titleTop,
        subtitleSpacing: CGFloat = 10
    ) {
        titleLabel
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: top)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailingLessThanOrEqual(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)

        guard let subtitleLabel else { return }

        subtitleLabel
            .addTo(view)
            .pinTop(toAnchor: titleLabel.bottomAnchor, constant: subtitleSpacing)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailing(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)
    }

    @discardableResult
    func layoutFormField(
        label: UILabel?,
        textField: UITextField,
        below anchor: NSLayoutYAxisAnchor,
        topSpacing: CGFloat,
        fieldTopSpacing: CGFloat = 11,
        height: CGFloat = 50
    ) -> NSLayoutYAxisAnchor {
        if let label {
            label
                .addTo(view)
                .pinTop(toAnchor: anchor, constant: topSpacing)
                .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)

            textField
                .addTo(view)
                .pinTop(toAnchor: label.bottomAnchor, constant: fieldTopSpacing)
                .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
                .pinTrailing(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)
                .setHeight(height)

            return textField.bottomAnchor
        }

        textField
            .addTo(view)
            .pinTop(toAnchor: anchor, constant: topSpacing)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailing(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)
            .setHeight(height)

        return textField.bottomAnchor
    }

    func layoutBottomLink(_ button: UIButton, bottom: CGFloat = -10) {
        button
            .addTo(view)
            .centerXOn(view)
            .pinBottom(toAnchor: view.safeAreaLayoutGuide.bottomAnchor, constant: bottom)
    }

    func layoutPrimaryFooterButton(
        _ button: UIButton,
        above anchor: NSLayoutYAxisAnchor? = nil,
        spacing: CGFloat = -25,
        bottom: CGFloat = -28,
        height: CGFloat = 86
    ) {
        button
            .addTo(view)
            .pinLeading(to: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.sideInset)
            .pinTrailing(to: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.sideInset)
            .setHeight(height)

        if let anchor {
            button.pinBottom(toAnchor: anchor, constant: spacing)
        } else {
            button.pinBottom(toAnchor: view.safeAreaLayoutGuide.bottomAnchor, constant: bottom)
        }
    }

    @discardableResult
    func layoutScreenTitle(
        _ titleLabel: UILabel,
        top: CGFloat = Constants.titleTop,
        leading: CGFloat = 16
    ) -> NSLayoutYAxisAnchor {
        titleLabel
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: top)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: leading)
        return titleLabel.bottomAnchor
    }

    func layoutHeaderActionButton(
        _ button: UIButton,
        top: CGFloat = Constants.titleTop,
        trailing: CGFloat = -16,
        size: CGFloat = 32
    ) {
        button
            .addTo(view)
            .pinTop(toAnchor: view.safeAreaLayoutGuide.topAnchor, constant: top)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: trailing)
            .setSize(width: size, height: size)
    }

    func layoutTableView(
        _ tableView: UITableView,
        below anchor: NSLayoutYAxisAnchor,
        topSpacing: CGFloat,
        horizontalInset: CGFloat = 0,
        bottom: CGFloat = 0
    ) {
        tableView
            .addTo(view)
            .pinTop(toAnchor: anchor, constant: topSpacing)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: horizontalInset)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -horizontalInset)
            .pinBottom(toAnchor: view.safeAreaLayoutGuide.bottomAnchor, constant: bottom)
    }

    func layoutCenteredEmptyLabel(
        _ label: UILabel,
        horizontalInset: CGFloat = 20
    ) {
        label.textAlignment = .center
        label
            .addTo(view)
            .centerXOn(view)
            .centerYOn(view)
            .pinLeft(toAnchor: view.safeAreaLayoutGuide.leftAnchor, constant: horizontalInset)
            .pinRight(toAnchor: view.safeAreaLayoutGuide.rightAnchor, constant: -horizontalInset)
    }
}
