import UIKit
import KavenegarCall
import CallKit


class CallViewController: UIViewController {
    
    @IBOutlet weak var callerUserNameLabel: UILabel!
    @IBOutlet weak var callStatusLabel: UILabel!
    @IBOutlet weak var muteView: UIView!
    @IBOutlet weak var muteImageView: UIImageView!
    @IBOutlet weak var speakerView: UIView!
    @IBOutlet weak var speakerImageView: UIImageView!
    @IBOutlet weak var hangupView: UIView!
    @IBOutlet weak var hangupImageView: UIImageView!
    @IBOutlet weak var buttonStackView: UIStackView!
    @IBOutlet      var buttonsView: [UIView]!
    @IBOutlet weak var connectionStatusLabel: UILabel!
    @IBOutlet weak var mediaStateLabel: UILabel!
    
    var hangupGesture: UITapGestureRecognizer!
    
    var audioManeger = AudioManeger()
    var call: Call!
    var callId: String!
    var accessToken: String!
    
    var cxCallProvider: CXProvider!
    var cxCallController: CXCallController!
    var cxCallUpdate: CXCallUpdate!
    
    var logger: Logger {
        return kavenegarCall.logger
    }
    
    var appApiToken: String {
        get {
            return UserDefaults.standard.value(forKey: "AppApiToken") as! String
        }
        set(newToken) {
            UserDefaults.standard.set(newToken, forKey: "AppApiToken")
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        gestureConfig()
        callKitConfig()
        config()
    }
    
    
}

extension CallViewController {
    
    func gestureConfig(){
        
        hangupGesture = UITapGestureRecognizer.init(target: self, action: #selector(self.hangupAction))
        self.hangupView.addGestureRecognizer(hangupGesture)
        self.hangupView.isUserInteractionEnabled = true
        
        let speakerGesture = UITapGestureRecognizer.init(target: self, action: #selector(self.speakerAction))
        self.speakerView.addGestureRecognizer(speakerGesture)
        self.speakerView.isUserInteractionEnabled = true
        
        let muteGesture = UITapGestureRecognizer.init(target: self, action: #selector(self.muteAction))
        self.muteView.addGestureRecognizer(muteGesture)
        self.muteView.isUserInteractionEnabled = true
        
    }
    
    func config(){
        
        for buttonView in buttonsView {
            buttonView.clipsToBounds = true
            buttonView.layer.cornerRadius = buttonView.frame.height / 2
            buttonView.isHidden = true
        }
        
       
        KavenegarCall.instance.initCall(callId: callId,accessToken: accessToken, listener: self,callback: { (status,call) in
            if status != .success {
                self.close()
                return
            }
            if let call = call {
                self.call = call
                
                call.onMessagingStateChanged = { event in
                    self.connectionStatusLabel.text = "Messaging State : \(event.oldState.rawValue) to \(event.newState.rawValue)"
                }
                call.onMediaStateChanged = { event in
                    self.mediaStateLabel.text =  "Media State : \(event.oldState.description) to \(event.newState.description)"
                }
                
                switch self.call.direction {
                case .outbound:
                    self.logger.info("Init outcoming call")
                    self.initOutcomingCall()
                case .inbound:
                    self.logger.info("Init incoming call")
                    self.initIncomingCall()
                }
            }
        })
        
    }
    
    func peerConnectionStateChanged(event:PeerConnectionStateChangedEvent){
        DispatchQueue.main.async {
            self.mediaStateLabel.text =  "Media State : \(event.oldState.description) to \(event.newState.description)"
        }
    }
    
    func initOutcomingCall(){
        
        setCallUI()
        startOutgoingCall(call: self.call)
        
    }
    
    func setCallUI(){
        callerUserNameLabel.text = call.receptor.userName
        callStatusLabel.text = "Calling"
        hangupView.isHidden = false
        muteView.isHidden = true
        speakerView.isHidden = true
    }
    
    func initIncomingCall(){
        
        do {
            try call.ringing()
            
            setAnswerUI()
            startIncomingCall(call: self.call)
        } catch let error {
            logger.error(error.localizedDescription)
            close()
        }
        
    }
    
    func setAnswerUI(){
        callerUserNameLabel.text = call.caller.userName
        callStatusLabel.text = "Answer"
        hangupView.isHidden = true
        speakerView.isHidden = true
        muteView.isHidden = true
    }
    
    func conversationViewStatus(){
        
        callStatusLabel.text = "Conversation"
        hangupView.isHidden = false
        speakerView.isHidden = false
        muteView.isHidden = false
        
    }
    
    func startCommiunication() {
        conversationViewStatus()
        audioManeger.stop()
    }
    
    func callAlert(){
        
        if let url = URL(string: "tel:\(self.call.receptor)") {
            UIApplication.shared.open(url , options: [:], completionHandler: nil)
        }
        
    }
    
    func close() {
        
        self.call?.dispose()
        self.audioManeger.stop()
        self.dismiss(animated: true)
        
    }
    

  
    
    
    // UI Events ==============================================
    
    
    @objc func hangupAction(){
        self.logger.info("Hangup")
        self.hangupGesture.isEnabled = false
        self.hangupView.isUserInteractionEnabled = false
        
        do {
            try self.call.hangup()
        } catch let error {
            logger.error(error.localizedDescription)
        }
        
    }
    
    
    @objc func speakerAction(){
        self.logger.info("Speaker")
        
        if audioManeger.isSpeakerEnabled {
            audioManeger.isSpeakerEnabled = false
            self.speakerView.backgroundColor = UIColor.clear
        } else {
            audioManeger.isSpeakerEnabled = true
            self.speakerView.backgroundColor = #colorLiteral(red: 0.5005699992, green: 0.5487136841, blue: 0.5537394285, alpha: 1)
        }
        
    }
    
    @objc func muteAction(){
        self.logger.info("Mute")
        self.muteCall()
    }
    
}

extension CallViewController: CallDelegate {
    
    func onCallStateChanged(state: CallStatus, isLocalChange: Bool) {
        self.logger.info(state.rawValue)
        self.callStatusLabel.text = state.rawValue
        
        switch state {
        case .trying:
            self.logger.info("Trying")
            self.audioManeger.playSound(soundName: "redphone_sonarping", type: .sonar)
            
        case .ringing:
            self.audioManeger.playSound(soundName: "redphone_outring", type: .ringing)
            
        case .accepted:
            self.audioManeger.stop()
            self.startCommiunication()
            
        case .conversation:
         
            self.audioManeger.stop()
            self.startCommiunication()
            
        case .finished:
            self.logger.info("call is : \(state.rawValue)")
        case .paused:
                self.logger.info("call is : \(state.rawValue)")
        case .flushed:
                self.logger.info("call is : \(state.rawValue)")
        }
        
    }
    
    func onCallFinished(reason: CallFinishedReason) {
        self.audioManeger.playSound(soundName: "webrtc_disconnected", type: .end)
        self.callStatusLabel.text = reason.rawValue
        self.endCall(call: self.call)
        self.close()
    }
    
    func onMediaStateChanged(event: MediaStateChangedEvent) {
        logger.info(event.newState.rawValue)
        
        if call.callerMediaState == MediaState.connected && call.receptorMediaState == MediaState.connected {
            logger.info("webrtc_completed")
            self.audioManeger.playSound(soundName: "webrtc_completed", type: .connected)
        }
        
        if event.newState == MediaState.disconnected {
            self.audioManeger.playSound(soundName: "webrtc_disconnected", type: .connected)
        }
        
        
    }
    
}
