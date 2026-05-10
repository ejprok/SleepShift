//
//  SceneDelegate.swift
//  SleepShift
//
//  Created by Edward Prokopik on 10/28/25.
//

import UIKit
import SwiftData
import EJComponent

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var appCoordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let container = (UIApplication.shared.delegate as! AppDelegate).modelContainer

        let window = UIWindow(windowScene: windowScene)
        let appCoordinator = AppCoordinator(window: window)
        let mainCoordinator = MainCoordinator(
            navigationController: appCoordinator.navigationController,
            modelContainer: container
        )

        SleepShiftManager.shared.setup(context: container.mainContext)

        appCoordinator.addChild(mainCoordinator)
        appCoordinator.start()
        mainCoordinator.start()

        self.window = window
        self.appCoordinator = appCoordinator
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        Task { await SleepShiftManager.shared.handleForeground() }
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
