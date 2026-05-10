//
//  RootViewController.swift
//  TemplateApp
//
//  Created by Edward Prokopik on 10/28/25.
//

import UIKit

final class RootViewController: UIViewController {
    weak var coordinator: MainCoordinator?
    
    init(coordinator: MainCoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Hello (UIKit)"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Tap me", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        view.addSubview(titleLabel)
        view.addSubview(actionButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),

            actionButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            actionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        actionButton.addTarget(self, action: #selector(didTap), for: .touchUpInside)
    }

    @objc private func didTap() {
        print("Tapped")
        // You can now use coordinator for navigation:
        // coordinator?.showSomeScreen()
    }
}

