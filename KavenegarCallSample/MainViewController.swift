//
//  ViewController.swift
//  KavenegarCallSample
//
//  Created by Mohsen Karimi on 11/26/18.
//  Copyright © 2018 Mohsen Karimi. All rights reserved.
//

import UIKit
import PushKit
import KavenegarCall

enum ViewStatus: String {
    case notConnected = "notConnected"
    case loggedIn = "loggedIn"
    case calling = "calling"
}

class MainViewController: UIViewController {

    var voipRegistry: PKPushRegistry!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var contentContainerView: UIView!
    @IBOutlet weak var loginView: UIView!
    @IBOutlet weak var mobileNumberTextField: UITextField!
    @IBOutlet weak var loginButtonOutlet: UIButton!
    @IBOutlet weak var callView: UIView!
    @IBOutlet weak var callUserNameTextField: UITextField!
    @IBOutlet weak var callButtonOutlet: UIButton!
  
    var appApiToken: String? {
        get {
            return UserDefaults.standard.value(forKey: "AppApiToken") as? String
        }
        set(newToken) {
            UserDefaults.standard.set(newToken, forKey: "AppApiToken")
        }
    }
    
    var pushNotificationToken: String? {
        get {
            return UserDefaults.standard.value(forKey: "PushNotificationToken") as? String
        }
        set(newToken) {
            UserDefaults.standard.set(newToken, forKey: "PushNotificationToken")
        }
    }
    
    var logger: Logger {
        return avanegar.logger
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        config()
        registerForVoIPPushes()
    }
}


//Config - Action
extension MainViewController {
    
    func config(){
      
        contentContainerView.frame.size.height = self.view.frame.height - self.callView.frame.height
        loginButtonOutlet.addTarget(self, action: #selector(self.loginButtonAction), for: .touchDown)
        callButtonOutlet.addTarget(self, action: #selector(self.callButtonAction), for: .touchDown)
        viewsStatus(info: .notConnected)
        
        if let loginName = UserDefaults.standard.value(forKey: "MobileNumber") as? String {
            self.mobileNumberTextField.text = loginName
        }
        
        if let callUserName = UserDefaults.standard.value(forKey: "CallUserName") as? String {
            self.callUserNameTextField.text = callUserName
        }
        
        if appApiToken != nil {
            self.viewsStatus(info: .loggedIn)
        }
        
    }
    
    func viewsStatus(info: ViewStatus){
        
        self.activityIndicator.stopAnimating()
        
        switch info {
        case .notConnected:
            self.callView.isHidden = true
            self.loginView.isHidden = false
            self.title = "Avanegar"
            self.navigationItem.leftBarButtonItem = nil
            self.navigationItem.rightBarButtonItem = nil
            
        case .loggedIn:
            self.loginView.isHidden = true
            self.callView.isHidden = false
            self.title = UserDefaults.standard.value(forKey: "MobileNumber") as? String
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Sign out", style: .plain, target: self, action: #selector(self.signOutAction))
            
            
        default:
            logger.info("default")
        }
        
    }
    
    
    @objc func signOutAction(){
        
        UserDefaults.standard.removeObject(forKey: "AppApiToken")
        self.viewsStatus(info: .notConnected)
        
    }
    
    @objc func loginButtonAction(){
        
        if (mobileNumberTextField.text?.isEmpty)! {
            return
        }
        
        UserDefaults.standard.setValue(mobileNumberTextField.text, forKey:"MobileNumber")
        
        self.activityIndicator.startAnimating()
        login(mobileNumber: self.mobileNumberTextField.text!) { (isSuccess, result) in
            DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            
            if isSuccess {
                self.appApiToken = result
                self.viewsStatus(info: .loggedIn)
                return
            }
            
            self.warningAlert(title: "Login", error: result)
            }
        }
        
    }
    
    @objc func callButtonAction(){
        
        if (callUserNameTextField.text?.isEmpty)! {
            return
        }
        
        UserDefaults.standard.setValue(callUserNameTextField.text, forKey:"CallUserName")
        
        logger.info("#####################################################################################")
        logger.info("Calling to \(String(describing: callUserNameTextField.text!))")
        
        self.activityIndicator.startAnimating()
        call(mobileNumber: callUserNameTextField.text!) { (status, result) in
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                if status != "success" {
                    self.logger.info(status)
                    self.warningAlert(title: "Call", error: status)
                    return
                }
                self.startCall(payload: (result?.rawString())!, direction: .outbound)
            }
        }
        
    }
    
    func warningAlert(title: String, error: String){
        
        let alert = UIAlertController(title: title, message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {  action in
            
        }))
        self.present(alert, animated: true, completion: nil)
        
    }
    
    
}

//PushKit
extension MainViewController: PKPushRegistryDelegate {
    
    func registerForVoIPPushes() {
        self.voipRegistry = PKPushRegistry(queue: nil)
        self.voipRegistry.delegate = self
        self.voipRegistry.desiredPushTypes = [.voIP]
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        self.logger.info("didInvalidatePushTokenFor")
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        self.pushNotificationToken = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
        logger.info("pushCredentials: \(String(describing: pushNotificationToken!))")
    }
    
    @available(iOS, introduced: 8.0, deprecated: 11.0)
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType){
        self.handlePushNotification(payload: payload)
    }
    
    @available(iOS 11.0, *)
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        self.handlePushNotification(payload: payload)
    }
    
    func handlePushNotification(payload: PKPushPayload){
        logger.info("didReceiveIncomingPushWith 10")
        
        guard let aps =  payload.dictionaryPayload["aps"] as? [String: Any],
            let alert = aps["alert"] as? [String: Any],
            let body = alert["body"] as? String
            else {
                self.warningAlert(title: "Push notification", error: "Parse json")
                return
        }
        
        self.startCall(payload: body, direction: .inbound)
    }
    
    
    func startCall(payload: String, direction: CallDirection){
    
        let json = JSON(parseJSON: payload)
        let accessToken = json["accessToken"].stringValue
        let callId = json["callId"].stringValue
        
        let callViewController = self.storyboard?.instantiateViewController(withIdentifier: "idCallViewController") as! CallViewController
        callViewController.callId = callId
        callViewController.accessToken = accessToken
        self.present(callViewController, animated: false, completion: nil)
        
    }
    
    
}


//API
extension MainViewController {
    
    func login(mobileNumber: String, callback: @escaping (Bool, String)->Void){
        
        let url = URL(string: "https://sample.kavenegar.io/authorize")!
        var request = URLRequest(url: url)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        let postString = "username=\(mobileNumber)&platform=ios&deviceId=\(UIDevice.current.identifierForVendor!)&notificationToken=\(self.pushNotificationToken!)"
        request.httpBody = postString.data(using: .utf8)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                callback(false, "Connection Error")
                return
            }
            
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                callback(false, "Request is not success, status code : \(httpStatus.statusCode)")
                return
            }
            
            let json = JSON(data: data)
            if let apiToken = json["apiToken"].string {
                callback(true, apiToken)
                return
            }
            
            let status = json["status"].stringValue
            callback(false, status)
            
        }
        task.resume()
    }
    
  
    func call(mobileNumber: String ,callback: @escaping (String, JSON?)->Void){
        let url = URL(string: "https://sample.kavenegar.io/calls")!
        var request = URLRequest(url: url)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.setValue(self.appApiToken!, forHTTPHeaderField: "Authorization")
        request.httpBody = ("receptor=" + mobileNumber).data(using: .utf8)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
                
            guard let data = data, error == nil else {
                callback("connection_error",nil)
                return
            }
                
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                callback("request_is_not_success",nil)
                return
            }
                
            let json = JSON(data: data)
            self.logger.info(json.debugDescription)
            callback("success", json)
        }
        task.resume()
    }

}
