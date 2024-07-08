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
    @Published var breakStarted:Date? = nil
    
    // Session
    @Published var phoneConnected:Bool = false
    @Published var totalBreaks:Int = 0
    @Published var todayBreaks:Int = 0
    @Published var design:CigDesign = CigDesign()
    
    var session: WCSession
    let functions = DataFunctionsWatch()
    
    init(session: WCSession = .default){
        self.session = session
        super.init()
        self.session.delegate = self
        session.activate()
        
        // Load saved total
        //self.totalBreaks = functions.load()
    }
    
    // MARK: Sessions
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        if let error = error { print(error.localizedDescription) }
    }
    
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        
        if session.isReachable {
            self.phoneConnected = true
            self.sendUpdate()
        } else {
            self.phoneConnected = false
        }
    }
    
    // Receive new update from phone
    func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        
        print("WATCH R - Recieved data")
        
        receiveUpdate(messageData) { replyData in
            
            print("WATCH R - Confirmation returned")
            replyHandler(replyData)
        }
        
    }
    
    // MARK: Public
    
    // Let watch know that smoking started
    
    
    func completedBreak() {
        self.totalBreaks += 1
        self.todayBreaks += 1
        sendUpdate()
    }
    
    // MARK: Private
    
    // Send new total to watch
    func sendUpdate() {
        
        // Check if watch is connected
        if session.isReachable {
            
            // Prepare update
            let update = WatchUpdateModel(
                updated: Date.now,
                breakStarted: self.breakStarted,
                totalBreaks: self.totalBreaks,
                todayBreaks: 0, 
                design: self.design /// not used
            )
            
            // Encode data
            if let updateData:Data = functions.encodeUpdate(from: update) {
                
                // Send data
                session.sendMessageData(updateData) { replyData in
                    
                    // Check if new total on watch is received back
                    if let replyUpdate:WatchUpdateModel = self.functions.decodeUpdate(from: replyData) {
                        
                        // Check if message was delivered
                        if replyUpdate.deliveryConfirmed {
                            print("Phone update sent and confirmed")
                        } else {
                            print("Phone update sent, but reply didn't match")
                        }
                    }
                }
            }
        }
    }
    
    private func receiveUpdate(_ updateRaw:Data, completion: (Data) -> Void) {
        
        print("WATCH R - Received update")
        
        // Decode update
        if let update = functions.decodeUpdate(from: updateRaw) {
            
            DispatchQueue.main.async {
                
                // Update breakstatus if needed
                if update.totalBreaks != self.totalBreaks { self.totalBreaks = update.totalBreaks }
                
                // Update today if needed
                if update.todayBreaks != self.todayBreaks { self.todayBreaks = update.todayBreaks }
                
                // Update status if needed
                if update.breakStarted != self.breakStarted { self.breakStarted = update.breakStarted }
                
                // Update design if necessary
                if update.design != self.design { self.design = update.design }
            }
            
            // Create confirmation reply
            completion(functions.replyData(confirmed: true))
            
        } else {
            
            // Create failure reply
            completion(functions.replyData(confirmed: false))
        }
    }
}
