//
//  WCSessionPhone.swift
//  NSSB
//
//  Created by Anders Munck on 09/06/2022.
//

import Foundation
import WatchConnectivity

class WCSessionPhone : NSObject,  WCSessionDelegate, ObservableObject {
    
    // Cigarette
    @Published var breakStarted:Date? = nil
    
    // Session
    @Published var sessionConnected:Bool = false
    @Published var data:NonSmokingData = NonSmokingData() { didSet { saveData() }}
    @Published var pendingUpload:Bool = false
    
    let functions = DataFunctionsPhone()
    
    var session: WCSession
    
    init(session: WCSession = .default){
        
        // Init watch session
        self.session = session
        super.init()
        self.session.delegate = self
        session.activate()
        
        // Load data to local state
        self.loadData()
    }
    
    
    // MARK: Session

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print(error ?? "no error")
        
        DispatchQueue.main.async {
            self.sessionConnected = true
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.sessionConnected = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.sessionConnected = false
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print(session.isReachable ? "Watch is reachable" : "Watch is not reachable")
        sendUpdate()
    }
    
    // Receive data from Watch
    func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        
        // If new data is received, merge it with existing
        receivedUpdate(messageData) { replyData in
            replyHandler(replyData)
        }
        
    }
    
    // MARK: Public functions
    
    
    // Let watch know that smoking started
    
    func completedBreak() {
        
        addCigarette()
        sendUpdate()
        
    }
    
    // MARK: Private
    
    private func addCigarette(_ missingBreaks: Int = 1) {
        
        DispatchQueue.main.async {
            for _ in (1...missingBreaks) {
                print("Added cigarette")
                self.data.cigDates.append(Date.now)
            }
        }
        
    }
    
    func sendUpdate() {
        
        // Check if watch is connected
        if session.isReachable {
            
            // Encode data
            if let updateData:Data = createUpdateData() {
                
                print("PHONE S - Created data to send")
                
                // Send data
                session.sendMessageData(updateData) { replyData in
                    
                    print("PHONE S - Data sent")
                    
                    // Check if new total on watch is received back
                    if let replyUpdate:WatchUpdateModel = self.functions.decodeUpdate(from: replyData) {
                        
                        print("PHONE S - reply data received")
                        
                        // Check if delivery was confirmed
                        if replyUpdate.deliveryConfirmed {
                            print("PHONE S - delivery confirmation received")
                        }
                    }
                }
            }
        }
        
        func createUpdateData(_ deliveryConfirmed: Bool = false) -> Data? {
            
            // Prepare update
            let update = WatchUpdateModel(
                updated: Date.now,
                breakStarted: self.breakStarted,
                totalBreaks: self.data.breaksTotal(),
                todayBreaks: self.data.breaksToday(),
                deliveryConfirmed: deliveryConfirmed
            )
            
            return functions.encodeUpdate(from: update)
        }
    }
    
    private func receivedUpdate(_ updateRaw:Data, completion:(Data) -> Void) {
        
        print("PHONE R -------------")
        
        
        // Decode update
        if let update = functions.decodeUpdate(from: updateRaw) {
            
            print("PHONE R - decoded update: \(update)")
            print("PHONE R - Local data: breakStarted = \(String(describing: self.breakStarted))")
            print("PHONE R - Local data: totalBreaks = \(self.data.breaksTotal())")
            
            // Update smoking if needed
            if update.breakStarted != self.breakStarted {
                DispatchQueue.main.async {
                    self.breakStarted = update.breakStarted
                }
            }
            
            // Update totals if needed
            if update.totalBreaks > self.data.breaksTotal() {
                
                let missingBreaks = update.totalBreaks - self.data.breaksTotal()
                
                print("PHONE R - added \(missingBreaks) break(s)")
                self.addCigarette(missingBreaks)
                
            }
        }
        
        // Return confirmation data
        completion(functions.replyData(confirmed: true))
        
    }
    
    private func loadData() {
        if let loadedData = functions.load() {
            DispatchQueue.main.async {
                self.data = loadedData
            }
        }
    }
    
    private func saveData() {
        functions.save(self.data)
    }
    /*
    private func syncData(_ receivedRaw: Data?) {
        
        // Is there a live session to sync through
        if session.isWatchAppInstalled && session.isReachable {
            
            // Did we receive data
            if let receivedData = functions.mergeData(receivedRaw, with: self.data) {
                
                
                
            }
            
            
            
            
        }
        
    }
    */
    /*func sendData(_ data:NonSmokingData) {
        
        let encodedData:Data? = functions.encode(from: self.data)
        
        if let encodedData = encodedData {
            
            session.sendMessageData(encodedData) { reply in
                
                let updatedData = self.functions.mergeData(reply, with: self.data)
                
                if let updatedData = updatedData {
                    self.data = updatedData
                }
                
            }
        }
    }
    */
    
}
