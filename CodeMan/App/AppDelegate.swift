//
//  AppDelegate.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/21/26.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
  static var orientationLock: UIInterfaceOrientationMask = .all

  func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    AppDelegate.orientationLock
  }
}
