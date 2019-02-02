//
//  AppDelegate.swift
//  KavenegarCallSample
//
//  Created by Mohsen Karimi on 11/26/18.
//  Copyright © 2018 Mohsen Karimi. All rights reserved.
//

import UIKit
import KavenegarCall


var backendApiPath = "http://192.168.1.188:3000"

var kavenegarCall : KavenegarCall {
    return KavenegarCall.instance
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        KavenegarCall.initialize(environment: Environment.production)
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        
    }

    func applicationWillTerminate(_ application: UIApplication) {
        
    }

}

extension String {
    func convertJsonToDictionary() -> [String: Any]? {
        if let data = self.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
}
