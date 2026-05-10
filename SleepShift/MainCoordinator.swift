//
//  MainCoordinator.swift
//  SleepShift
//
//  Created by Edward Prokopik on 10/28/25.
//

import UIKit
import SwiftData
import EJComponent

class MainCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    let modelContainer: ModelContainer

    init(navigationController: UINavigationController, modelContainer: ModelContainer) {
        self.navigationController = navigationController
        self.modelContainer = modelContainer
    }

    func start() {
        // Routing logic replaced in Phase 8 — placeholder keeps the coordinator chain valid
        let rootViewController = RootViewController(coordinator: self)
        navigationController.pushViewController(rootViewController, animated: false)
    }
}

