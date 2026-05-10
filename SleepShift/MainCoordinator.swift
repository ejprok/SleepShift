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

    // MARK: - Home

    func showHome() {
        let view = HomeView(manager: SleepShiftManager.shared, onShowHistory: { [weak self] in
            self?.showHistory()
        })
        .modelContainer(modelContainer)

        navigationController.setViewControllers([UIHostingController(rootView: view)], animated: true)
    }

    // MARK: - History

    func showHistory() {
        let view = HistoryView()
            .modelContainer(modelContainer)

        navigationController.pushViewController(UIHostingController(rootView: view), animated: true)
    }
}

