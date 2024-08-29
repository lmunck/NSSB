//
//  WCSessionPhone.swift
//  NSSB
//
//  Created by Anders Munck on 09/06/2022.
//

import Foundation
import WatchConnectivity

class WCSessionPhone : NSObject,  WCSessionDelegate, ObservableObject {
    
    // Cigrette
    @Published var data:NonSmokingData = NonSmokingData() { didSet { sendUpdate() }}
    @Published var lastData:NonSmokingData = NonSmokingData()
    
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
        if let loadedData = functions.load() {
            DispatchQueue.main.async {
                print("Loaded data")
                self.lastData = loadedData
                self.data = loadedData
            }
        }
    }
    
    
    // MARK: Session

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error { print("Session - ActivationDidComplete - \(error.localizedDescription)") }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("Session - sessionReachabilityDidChange  \(session.isReachable ? "ACTIVE" : "INACTIVE")")
        self.connectionUpdate(session.isReachable)
        sendUpdate()
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        
        print("Session - didReceiveMessageData")
        self.receivedUpdate(messageData) { replyData in
            print("Session - replyHandler")
            replyHandler(replyData)
        }
        
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
    
    // Send new total to watch
    func sendUpdate() {
        
        if self.data != self.lastData {
            
            print("sendUpdate() - Found changes")
            let saveData = self.data
            
            // Save update
            self.functions.save(saveData)
            DispatchQueue.main.async {
                self.lastData = saveData
            }
            
            // Check if watch is connected
            if session.isReachable {
                
                print("sendUpdate() - Encoding data")
                
                // Encode data
                if let updateData:Data = functions.encodeData(from: saveData) {
                    
                    print("sendUpdate() - Sending data")
                    
                    // Send data
                    session.sendMessageData(updateData, replyHandler: { confirmationData in
                        
                        print("sendUpdate() - Received confirmation")
                        
                        if let confirmationObject = self.functions.decodeData(from: confirmationData) {
                            
                            print("sendUpdate() - Confirmation decoded")
                            
                            if confirmationObject == saveData {
                                print("sendUpdate() - Confirmation checks out")
                            } else {
                                print("sendUpdate() - Local data is not the same \n\n\(saveData)\nvs\n\(confirmationObject)")
                            }
                        } else {
                            print("sendUpdate() - Confirmation not decoded")
                        }
                        
                        
                    })
                }
            } else {
                print("sendUpdate() - Device not reachable")
            }
            
        } else {
            print("SendUpdate() - No changes")
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
                    print("receivedUpdate() - merged and updated")
                    
                    // Save data
                    self.functions.save(mergedObject)
                    
                    // Schedule update of self
                    DispatchQueue.main.async {
                        self.lastData = mergedObject
                        self.data = mergedObject
                    }
                    
                    // Confirm delivery
                    if let confirmationData = self.functions.encodeData(from: mergedObject) {
                        completion(confirmationData)
                    } else {
                        completion(updateRaw)
                    }
                    
                } else {
                    print("receivedUpdate() - unable to merge")
                    completion(updateRaw)
                }
            } else {
                completion(updateRaw)
            }
            
        } else {
            print("receivedUpdate() - unable to Decode")
            completion(updateRaw)
        }
        
    }
}
