//
//  AppDelegate.swift
//  SleepShift
//
//  Created by Edward Prokopik on 10/28/25.
//

import UIKit
import SwiftData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    let modelContainer: ModelContainer = {
        try! ModelContainer(for: ShiftProgram.self, WakeAttempt.self)
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // BGAppRefreshTask registration added in Phase 9
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}

