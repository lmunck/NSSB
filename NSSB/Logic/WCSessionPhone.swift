//
//  WCSessionPhone.swift
//  NSSB
//
//  Created by Anders Munck on 09/06/2022.
//

// Main view-controller with logic for maintaining connection to Apple Watch and storing data
// Complying with WCSessionDelegate is what allows Watch Connection and the Session functions, and the "only phone" section is because the other parts can be used on the watch as well

import Foundation
import WatchConnectivity

class WCSessionPhone : NSObject,  WCSessionDelegate, ObservableObject {
    
    // Cigrette
    @Published var data:NonSmokingData = NonSmokingData(lastUpdate: Date.distantPast) {
        didSet {
            // When it changed, not when it was sent. See NonSmokingData.touch.
            guard stamping == false else { return }
            stamping = true
            data.touch(ifChangedFrom: oldValue)
            stamping = false

            // Persist break history and the name straight away - neither can
            // be recreated if the app is killed before it backgrounds, and a
            // rolled name is not something the user can simply type again.
            // Both are discrete changes. Colours and width still save on scene
            // phase changes, so dragging a slider does not write to disk on
            // every frame.
            if oldValue.breaks != data.breaks
                || oldValue.breakStarted != data.breakStarted
                || oldValue.cigDesign.title != data.cigDesign.title {
                save()
            }
            sendUpdate()
        }
    }
    var lastReceived:NonSmokingData? = nil
    
    /// Stops the stamp from re-entering its own observer.
    private var stamping = false
    
    // Session
    @Published var connected:Bool = false
    
    // Dependencies
    var session: WCSession
    let functions = CodingFunctions()
    
    init(session: WCSession = .default){
        
        // Init watch session
        self.session = session
        super.init()
        self.session.delegate = self
        session.activate()
        
        // Load data
        load()
        
    }
    
    func load() {
        if let loadedData = functions.load() {
            Log.sync.debug("Loaded data \(loadedData.breaks.count)")
            self.data = loadedData
        } else {
            Log.sync.error("Load failed")
        }
    }
    
    func save() {
        functions.save(self.data)
    }
    
    // MARK: Session

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error { Log.sync.error("Session - ActivationDidComplete - \(error.localizedDescription)") }
        connectionUpdate(session.isReachable)
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        Log.sync.debug("Session - sessionReachabilityDidChange  \(session.isReachable ? "ACTIVE" : "INACTIVE")")
        self.connectionUpdate(session.isReachable)
        if session.isReachable {
            sendUpdate()
        }
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        
        Log.sync.debug("Session - didReceiveMessageData")
        self.receivedUpdate(messageData) { replyData in
            Log.sync.debug("Session - replyHandler")
            replyHandler(replyData)
        }
        
    }
    
    
    // MARK: Got a light?
    
    /// Taps the wrist when somebody in the courtyard answered your ask.
    ///
    /// Deliberately not queued. transferUserInfo would deliver this later,
    /// and a tap on the wrist ten minutes after the fact is not a message
    /// about somebody lighting your cigarette - it is a stranger tapping you
    /// for no reason. So if the watch is not there, nothing happens.
    ///
    /// No payload beyond the event. The watch has no courtyard, knows nobody
    /// out there, and does not need to.
    func tellWatchYouWereLit() {
        
        guard session.isReachable else {
            Log.sync.debug("Session - watch not reachable, no haptic")
            return
        }
        
        session.sendMessage(
            [WatchEvent.key: WatchEvent.litByStranger],
            replyHandler: nil,
            errorHandler: { error in
                Log.sync.error("Session - haptic not delivered: \(error.localizedDescription)")
            }
        )
    }
    
    /// The one thing the phone ever says to the watch that is not data.
    enum WatchEvent {
        static let key = "event"
        static let litByStranger = "litByStranger"
    }
    
    // MARK: Only Phone
    func sessionDidBecomeInactive(_ session: WCSession) {
        connectionUpdate(session.isReachable)
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        connectionUpdate(session.isReachable)
    }
    
    
    
    func connectionUpdate(_ newState: Bool) {
        if self.connected != newState {
            DispatchQueue.main.async {
                self.connected = newState
            }
        }
    }
    
    private func updateData(to update: NonSmokingData, completion: @escaping () -> Void) {
        self.functions.save(update)
        DispatchQueue.main.async {
            self.data = update
            completion()
        }
    }
    
    // Send new total to watch
    func sendUpdate() {
        
        // Sent exactly as it stands, stamp included: the stamp says when
        // this was changed, and sending it is not changing it.
        let sendObject = self.data
        
        // Check if watch is connected
        if session.isReachable {
            
            if self.lastReceived != sendObject {
                
                // Encode data
                if let sendData:Data = functions.encodeData(from: sendObject) {
                    Log.sync.debug("sendUpdate() - Data encoded - SUCCESS")
                    
                    // Send data
                    session.sendMessageData(sendData, replyHandler: { confirmationData in
                        Log.sync.debug("sendUpdate() - Confirmation received")
                        
                        if let confirmationObject = self.functions.decodeData(from: confirmationData) {
                            Log.sync.debug("sendUpdate() - Confirmation decoded")
                            
                            if confirmationObject == sendObject {
                                Log.sync.debug("sendUpdate() - Confirmation checks out")
                            } else {
                                Log.sync.error("sendUpdate() - Confirmation failed:")
                                confirmationObject.compare(to: sendObject)
                            }
                        } else {
                            Log.sync.debug("sendUpdate() - Confirmation not decoded")
                        }
                        
                    })
                      
                } else {
                    Log.sync.error("sendUpdate() - Data encoded - FAIL")
                }
                
            } else {
                Log.sync.debug("sendUpdate() - New data is the same as last received. Not sending")
            }
            
        } else {
            Log.sync.debug("sendUpdate() - Session.isReachable = FALSE")
        }
         
    }
    
    func receivedUpdate(_ updateRaw:Data, completion: @escaping (Data) -> Void) {
        
        Log.sync.debug("receivedUpdate()")
        
        // Decode update
        if let receivedObject:NonSmokingData = functions.decodeData(from: updateRaw) {
            
            Log.sync.debug("receivedUpdate() - update decoded, lastReceived updated")
            self.lastReceived = receivedObject
            
            if receivedObject != self.data {
                
                Log.sync.debug("receivedUpdate() - change detected")
                self.data.compare(to: receivedObject)
                
                // Merge received object with local object
                if let mergedObject = self.data.merge(from: receivedObject) {
                    
                    Log.sync.debug("receivedUpdate() - update merged")
                    
                    self.updateData(to: mergedObject) {
                        
                        Log.sync.debug("receivedUpdate() - update updated")
                        
                        // Confirm delivery
                        if let confirmationData = self.functions.encodeData(from: mergedObject) {
                            Log.sync.debug("receivedUpdate() - confirmation encoded")
                            completion(confirmationData)
                        } else {
                            Log.sync.error("receivedUpdate() - confirmation encoding FAIL")
                            completion(updateRaw)
                        }
                        
                    }
                    
                } else {
                    Log.sync.debug("receivedUpdate() - update merge no change detected")
                    completion(updateRaw)
                }
            } else {
                Log.sync.debug("receivedUpdate() - no change detected")
                completion(updateRaw)
            }
            
        } else {
            Log.sync.error("receivedUpdate() - update decoded FAIL")
            completion(updateRaw)
        }
        
    }
}
