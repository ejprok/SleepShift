//
//  MainCoordinator.swift
//  SleepShift
//
//  Created by Edward Prokopik on 10/28/25.
//

import UIKit
import SwiftUI
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
        let manager = SleepShiftManager.shared
        if manager.activeProgram != nil {
            showHome()
        } else {
            showOnboarding()
        }
    }

    // MARK: - Onboarding

    func showOnboarding() {
        let view = OnboardingView { [weak self] startTime, targetTime in
            Task { @MainActor in
                await self?.handleProgramStart(startTime: startTime, targetTime: targetTime)
            }
        }
        navigationController.setViewControllers([UIHostingController(rootView: view)], animated: false)
    }

    @MainActor
    private func handleProgramStart(startTime: Date, targetTime: Date) async {
        let context = modelContainer.mainContext
        let program = ShiftProgram(startWakeTime: startTime, targetWakeTime: targetTime)
        context.insert(program)
        try? context.save()
        SleepShiftManager.shared.activateProgram(program)
        await SleepShiftManager.shared.requestAuthorization()
        await SleepShiftManager.shared.scheduleNextAlarm(forDay: 1)
        showHome()
    }

    // MARK: - Home (Phase 6)

    func showHome() {
        // HomeView wired in Phase 6 — placeholder
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "Home — Phase 6"
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
        ])
        navigationController.setViewControllers([vc], animated: true)
    }

    // MARK: - History (Phase 7)

    func showHistory() {
        // HistoryView wired in Phase 7
    }
}

