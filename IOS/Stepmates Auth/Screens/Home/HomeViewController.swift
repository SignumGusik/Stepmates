//
//  HomeViewController.swift
//  Stepmates Auth
//
//  Created by Диана on 24/01/2026.
//

import UIKit
import Combine

protocol HomeNavDelegate: AnyObject {
    func onLogoutTapped()
}

class HomeViewController: UIViewController {
    
    private lazy var infoText = UITextView.makeTextField()
    private lazy var fetchDataButton = UIButton.makeButton(title: "Fetch Secure Data", target: self, action: #selector(self.onFetchTapped))
    private lazy var resetButton = UIButton.makeButton(title: "Reset Text", target: self, action: #selector(self.onResetTextTapped))
    private lazy var logoutButton = UIButton.makeButton(title: "Logout", target: self, action: #selector(self.onLogoutTapped))
    
    private var concellables = Set<AnyCancellable>()
    
    weak var navDelegate: HomeNavDelegate?
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
extension HomeViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupObservers()
    }
}

// MARK: - View Setup/Configuration
private extension HomeViewController {
    
    func setupViews() {
        title = "Home"
        view.backgroundColor = .white
        
        infoText
            .addTo(view)
            .centerOn(view)
            .setDefaultFieldSize(superview: view)
        
        infoText.text = "Tap Fetch Button to fetch secured.data"
        
        fetchDataButton
            .addTo(view)
            .centerXOn(view)
            .pinTop(toAnchor: infoText.bottomAnchor, constant: 10)
        
        resetButton
            .addTo(view)
            .centerXOn(view)
            .pinTop(toAnchor: fetchDataButton.bottomAnchor, constant: 25)
        
        logoutButton
            .addTo(view)
            .centerXOn(view)
            .pinTop(toAnchor: resetButton.bottomAnchor, constant: 10)
    }
    
}
// MARK: -Observers
private extension HomeViewController {
    func setupObservers() {
        
        viewModel.$infoText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newText in
                self?.infoText.text = newText }.store(in: &concellables)
    }
    
    
}

// MARK: - Actions
private extension HomeViewController {
    @objc func onFetchTapped() {
        Task {
            do {
                try await viewModel.fetchSecureData()
                
            } catch {
                await MainActor.run {
                    [weak self] in
                    self?.showOkAlert(title:"Error", message: error.localizedDescription)
                }
            }
        }
        
    }
    @objc func onResetTextTapped() {
        viewModel.resetInfoText()
        
    }
    @objc func onLogoutTapped() {
        navDelegate?.onLogoutTapped()
    }
    
}

