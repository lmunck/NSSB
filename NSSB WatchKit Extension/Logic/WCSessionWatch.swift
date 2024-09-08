//
//  WCSessionWatch.swift
//  NSSB WatchKit Extension
//
//  Created by Anders Munck on 09/06/2022.
//

import Foundation
import WatchConnectivity

class WCSessionWatch : NSObject,  WCSessionDelegate, ObservableObject{
    
    // Cigarette
    @Published var data:NonSmokingData = NonSmokingData(lastUpdate: Date.distantPast) { didSet { sendUpdate() }}
    var lastUpdate:NonSmokingData? = nil
    
    // Session
    @Published var connected:Bool = false
    
    // Dependencies
    var session: WCSession
    let functions = CodingFunctions()
    
    init(session: WCSession = .default){
        
        // Activate phone connection
        self.session = session
        super.init()
        self.session.delegate = self
        session.activate()
        
        // Load data
        if let loadedData = functions.load() {
            self.updateData(to: loadedData)
        }
    }
    
    // MARK: Sessions
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error { print("Session - ActivationDidComplete - \(error.localizedDescription)") }
        connectionUpdate(session.isReachable)
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("Session - sessionReachabilityDidChange  \(session.isReachable ? "ACTIVE" : "INACTIVE")")
        self.connectionUpdate(session.isReachable)
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        
        print("Session - didReceiveMessageData")
        self.receivedUpdate(messageData) { replyData in
            print("Session - replyHandler")
            replyHandler(replyData)
        }
        
    }
    
    
    func connectionUpdate(_ newState: Bool) {
        if self.connected != newState {
            DispatchQueue.main.async {
                self.connected = newState
            }
        }
    }
    
    // Send new total to watch
    private func updateData(to update: NonSmokingData) {
        self.functions.save(update)
        DispatchQueue.main.async {
            self.data = update
        }
    }
    
    // Send new total to watch
    func sendUpdate() {
        
        var sendObject = self.data
        sendObject.lastUpdate = Date.now
        
        // Check if watch is connected
        if session.isReachable {
            print("sendUpdate() - Session.isReachable = TRUE")
            
            // Encode data
            if let sendData:Data = functions.encodeData(from: sendObject) {
                print("sendUpdate() - Data encoded - SUCCESS")
                
                // Send data
                session.sendMessageData(sendData, replyHandler: { confirmationData in
                    print("sendUpdate() - Confirmation received")
                    
                    if let confirmationObject = self.functions.decodeData(from: confirmationData) {
                        print("sendUpdate() - Confirmation decoded")
                        
                        if confirmationObject == sendObject {
                            print("sendUpdate() - Confirmation checks out")
                        } else {
                            print("sendUpdate() - Confirmation failed:")
                            confirmationObject.compare(to: sendObject)
                        }
                    } else {
                        print("sendUpdate() - Confirmation not decoded")
                    }
                    
                })
            } else {
                print("sendUpdate() - Data encoded - FAIL")
            }
        } else {
            print("sendUpdate() - Session.isReachable = FALSE")
        }
         
    }
    
    func receivedUpdate(_ updateRaw:Data, completion:(Data) -> Void) {
        
        print("receivedUpdate()")
        
        // Decode update
        if let receivedObject:NonSmokingData = functions.decodeData(from: updateRaw) {
            
            print("receivedUpdate() - update decoded")
            
            if receivedObject != self.data {
                
                print("receivedUpdate() - change detected")
                
                // Merge received object with local object
                if let mergedObject = self.data.merge(from: receivedObject) {
                    
                    print("receivedUpdate() - update merged")
                    
                    self.updateData(to: mergedObject)
                    
                    print("receivedUpdate() - update updated")
                    
                    // Confirm delivery
                    if let confirmationData = self.functions.encodeData(from: mergedObject) {
                        print("receivedUpdate() - confirmation encoded")
                        completion(confirmationData)
                    } else {
                        print("receivedUpdate() - confirmation encoding FAIL")
                        completion(updateRaw)
                    }
                    
                } else {
                    print("receivedUpdate() - update merge FAIL")
                    completion(updateRaw)
                }
            } else {
                print("receivedUpdate() - no change detected")
                completion(updateRaw)
            }
            
        } else {
            print("receivedUpdate() - update decoded FAIL")
            completion(updateRaw)
        }
        
    }
}
