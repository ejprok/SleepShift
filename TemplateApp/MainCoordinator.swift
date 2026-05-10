//
//  MainCoordinator.swift
//  TemplateApp
//
//  Created by Edward Prokopik on 10/28/25.
//

import UIKit
import EJComponent

class MainCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        let rootViewController = RootViewController(coordinator: self)
        navigationController.pushViewController(rootViewController, animated: false)
    }
}

