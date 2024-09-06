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
    @Published var data:NonSmokingData = NonSmokingData() { didSet { sendUpdate() }}
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
    private func updateData(to: NonSmokingData) {
        if lastUpdate == nil {
            self.lastUpdate = to
            DispatchQueue.main.async {
                self.data = to
            }
        } else if to != lastUpdate {
            self.lastUpdate = to
            self.functions.save(to)
            DispatchQueue.main.async {
                self.data = to
            }
        }
    }
    
    // Send new total to watch
    func sendUpdate() {
        
        let sendObject = self.data
        
        // Save update
        self.functions.save(sendObject)
        
        // Check if watch is connected
        if session.isReachable {
            print("sendUpdate() - Encoding data")
            
            // Encode data
            if let sendData:Data = functions.encodeData(from: sendObject) {
                print("sendUpdate() - Sending data")
                
                // Send data
                session.sendMessageData(sendData, replyHandler: { confirmationData in
                    print("sendUpdate() - Received confirmation")
                    
                    if let confirmationObject = self.functions.decodeData(from: confirmationData) {
                        print("sendUpdate() - Confirmation decoded")
                        
                        if confirmationObject == sendObject {
                            print("sendUpdate() - Confirmation checks out")
                        } else {
                            print("sendUpdate() - Local data is not the same: '\(sendObject.cigDesign.title)' vs '\(confirmationObject.cigDesign.title)'")
                        }
                    } else {
                        print("sendUpdate() - Confirmation not decoded")
                    }
                    
                })
            }
        } else {
            print("sendUpdate() - Device not reachable")
        }
         
    }
    
    func receivedUpdate(_ updateRaw:Data, completion:(Data) -> Void) {
        
        print("receivedUpdate()")
        
        // Decode update
        if let receivedObject:NonSmokingData = functions.decodeData(from: updateRaw) {
            
            print("receivedUpdate() - decoded update")
            
            if receivedObject != self.data {
                
                // Merge received object with local object
                if let mergedObject = self.data.merge(from: receivedObject) {
                    
                    print("receivedUpdate() - merged")
                    
                    self.updateData(to: mergedObject)
                    
                    print("receivedUpdate() - saved and updated")
                    
                    // Confirm delivery
                    if let confirmationData = self.functions.encodeData(from: mergedObject) {
                        print("receivedUpdate() - encoded confirmation")
                        completion(confirmationData)
                    } else {
                        print("receivedUpdate() - unable to encode confirmation")
                        completion(updateRaw)
                    }
                    
                } else {
                    print("receivedUpdate() - unable to merge")
                    completion(updateRaw)
                }
            } else {
                print("receivedUpdate() - unable to detect changes")
                completion(updateRaw)
            }
            
        } else {
            print("receivedUpdate() - unable to Decode")
            completion(updateRaw)
        }
        
    }
}
