import CallKit
import AVFoundation
import KavenegarCall
import WebRTC

extension CallViewController: CXProviderDelegate {
    
    func callKitConfig() {
        
        let cxProviderConfig = CXProviderConfiguration(localizedName: "KavenegarCall Sample")
        cxProviderConfig.maximumCallGroups = 1
        cxProviderConfig.maximumCallsPerCallGroup = 1
        cxProviderConfig.supportsVideo = false
        cxCallProvider = CXProvider(configuration: cxProviderConfig)
        cxCallProvider.setDelegate(self, queue: nil)
        
        cxCallController = CXCallController()
        
        cxCallUpdate = CXCallUpdate()
        cxCallUpdate.supportsDTMF = false
        cxCallUpdate.supportsHolding = false
        cxCallUpdate.supportsGrouping = false
        cxCallUpdate.supportsUngrouping = false
        cxCallUpdate.hasVideo = false
        
    }
    
    
    
    /// Send a call
    ///
    /// - Parameter call: call
    func startOutgoingCall(call: Call) {
        
        guard let callID = UUID(uuidString: call.id) else  {
            return
        }
        
        let callHandle = CXHandle(type: .generic, value: call.receptor.userName)
        let startCallAction = CXStartCallAction(call: callID, handle: callHandle)
        startCallAction.isVideo = false
        let transaction = CXTransaction(action: startCallAction)
        
        cxCallController.request(transaction)  { error in
            if let error = error {
                self.logger.error("CallKit startOutgoingCall request failed: \(error.localizedDescription)")
                return
            }
            
            self.audioManeger.configureAudioSession()
            
        }
        
    }
    
    /// Receive Call
    ///
    /// - Parameter call: call
    func startIncomingCall(call: Call) {
        
        guard let callID = UUID(uuidString: call.id) else {
            return
        }
        
        self.cxCallUpdate.remoteHandle = CXHandle(type: .generic, value: call.caller.userName)
        
        self.cxCallProvider.reportNewIncomingCall(with: callID, update: cxCallUpdate) { error in
            if let error = error {
                self.logger.error("CallKit startIncomingCall request was failed : \(error.localizedDescription)")
                return
            }
            self.audioManeger.configureAudioSession()
        }
        
    }
    
    
    
    /// End call
    ///
    /// - Parameter call: call
    func endCall(call: Call) {
        guard let uuid = UUID(uuidString: call.id) else {
            return
        }
        let transaction = CXTransaction(action: CXEndCallAction(call: uuid))
        self.audioManeger.stop()
        cxCallController.request(transaction) { error in
            if let error = error {
                self.logger.error("CallKit endCall request was failed: \(error.localizedDescription).")
                return
            }
        }
    }
    
    
    func endAllCalls(){
        for call in self.cxCallController.callObserver.calls {
            
            let endCallAction = CXEndCallAction(call: call.uuid)
            let transaction = CXTransaction(action: endCallAction)
            
            cxCallController.request(transaction) { error in
                if let error = error {
                    NSLog("EndCallAction transaction request failed: \(error.localizedDescription).")
                    return
                }
            }
            
        }
    }
    
    /// mute call
    func muteCall(){
        
        let setMutedCallAction = CXSetMutedCallAction(call: UUID(uuidString: self.call.id)!, muted: avanegar.peerConnection.isMuted)
        let transaction = CXTransaction(action: setMutedCallAction)
        
        cxCallController.request(transaction) { error in
            if let error = error {
                self.logger.error("CallKit muteCall request was failed: \(error.localizedDescription).")
                self.mute()
                return
            }
        }
        
    }
    
    
    func mute(){
        
        if avanegar.peerConnection.isMuted {
            avanegar.peerConnection.isMuted = false
            self.muteView.backgroundColor = UIColor.clear
        }else{
            avanegar.peerConnection.isMuted = true
            self.muteView.backgroundColor = #colorLiteral(red: 0.5005699992, green: 0.5487136841, blue: 0.5537394285, alpha: 1)
        }
        
    }
    
    
    func providerDidReset(_ provider: CXProvider) {
        logger.info(provider.debugDescription)
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        logger.info("CXAnswerCallAction \(provider.debugDescription, action.debugDescription)")
        action.fulfill()
        do {
            try self.call.accept()
            self.startCommiunication()
            
        } catch let error {
            logger.error(error.localizedDescription)
        }
        
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        logger.info("CallKit endCallEvent -> \(provider.debugDescription, action.debugDescription)")
        action.fulfill()
        if self.call.status == .finished {
            logger.info("CallKit \(self.call.id!) is finished already ")
            return
        }
        do {
            if self.call.direction == .inbound && self.call.status == .ringing {
                try self.call.reject()
            } else {
                try self.call.hangup()
            }
            
        } catch let error {
            logger.error("CallKit endCallEvent was failed \(error.localizedDescription)")
            action.fail()
        }
        
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        self.mute()
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        audioManeger.configureAudioSession()
    }
    
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        audioManeger.configureAudioSession()
    }
    
    func providerDidBegin(_ provider: CXProvider) {
   
    }

}
