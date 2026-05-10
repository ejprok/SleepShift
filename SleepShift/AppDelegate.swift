//
//  AppDelegate.swift
//  SleepShift
//
//  Created by Edward Prokopik on 10/28/25.
//

import UIKit
import SwiftData
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    static let bgTaskID = "com.prokopik.sleepshift.refresh"

    let modelContainer: ModelContainer = {
        try! ModelContainer(for: ShiftProgram.self, WakeAttempt.self)
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppDelegate.bgTaskID, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task {
                await SleepShiftManager.shared.handleForeground()
                refreshTask.setTaskCompleted(success: true)
            }
            AppDelegate.scheduleBackgroundRefresh()
            refreshTask.expirationHandler = { refreshTask.setTaskCompleted(success: false) }
        }
        return true
    }

    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: bgTaskID)
        // iOS schedules at its discretion; earliest wakeup is ~1 hour from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}

