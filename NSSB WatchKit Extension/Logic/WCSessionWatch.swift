//
//  WCSessionWatch.swift
//  NSSB WatchKit Extension
//
//  Created by Anders Munck on 09/06/2022.
//

import Foundation
import WatchConnectivity
import WatchKit

class WCSessionWatch : NSObject,  WCSessionDelegate, ObservableObject{
    
    // Cigarette
    @Published var data:NonSmokingData = NonSmokingData(lastUpdate: Date.distantPast) {
        didSet {
            // When it changed, not when it was sent. See NonSmokingData.touch
            // - the phone does the same, and it has to be both or neither.
            guard stamping == false else { return }
            stamping = true
            data.touch(ifChangedFrom: oldValue)
            stamping = false
            save()
            // Keep the complication current. Reloads only when something it
            // shows changed - the system budgets timeline reloads.
            SharedContainer.write(data)
            sendUpdate()
        }
    }
    var lastReceived:NonSmokingData? = nil
    
    /// Stops the stamp from re-entering its own observer.
    private var stamping = false
    
    /// Who is standing with you, for as long as they are.
    ///
    /// Not part of `data`, and deliberately so. Company is never saved, never
    /// merged and never stamped: it lasts exactly as long as the cigarettes
    /// do and nothing about it is kept, which is the first principle of the
    /// layer it comes from. Putting it in the file that gets written to disk
    /// and ordered by `lastUpdate` would break that twice over.
    ///
    /// Only the phone ever writes one, because only the phone has a
    /// courtyard. The watch receives it, draws it and forgets it.
    @Published private(set) var company:BreakCompany = .nobody
    
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
    
    // MARK: Sessions
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error { Log.sync.error("Session - ActivationDidComplete - \(error.localizedDescription)") }
        connectionUpdate(session.isReachable)
        
        guard activationState == .activated else { return }
        
        // Anything the phone sent while this app wasn't running arrives as the
        // latest application context. Merge it first, then offer our own state.
        let pending = session.receivedApplicationContext
        if pending.isEmpty == false { receivedContext(pending) }
        DispatchQueue.main.async { self.sendUpdate() }
    }
    
    /// The background channel: the system keeps only the latest context and
    /// delivers it when this app next runs, so nothing is lost while the phone
    /// is out of reach. No reply is possible, so it goes through the same merge
    /// as a live message and the confirmation is simply dropped.
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Log.sync.debug("Session - didReceiveApplicationContext")
        receivedContext(applicationContext)
    }
    
    private func receivedContext(_ context: [String: Any]) {
        
        // Whoever was standing with you when the phone last spoke. No key
        // means nobody - the context is replaced whole, so an absent key is
        // an answer rather than a gap.
        //
        // No tap on the wrist for this one. A context can be hours old by the
        // time this app runs, and company that may have finished long ago is
        // not something to buzz about. The live message is where that would
        // belong, if it belonged anywhere.
        received(company: context[WatchEventKeys.companyKey] as? Data)
        
        guard let contextData = context[CodingFunctions.contextKey] as? Data else {
            Log.sync.debug("receivedContext() - no data in context")
            return
        }
        receivedUpdate(contextData) { _ in }
    }
    
    /// Takes the phone's word for who is out here with you.
    ///
    /// Trusted as it stands rather than merged, because there is nothing to
    /// merge: the watch has no opinion about the courtyard and can never have
    /// formed one. What saves this from the staleness a merge would have
    /// guarded against is that every companion carries the instant their own
    /// cigarette was lit, and the view draws nobody whose cigarette has
    /// burned out.
    private func received(company payload: Data?) {
        
        let arriving = payload.flatMap { BreakCompany(payload: $0) } ?? .nobody
        
        guard arriving != company else { return }
        Log.sync.debug("receivedCompany() - \(arriving.beside.count) beside you")
        
        DispatchQueue.main.async {
            self.company = arriving
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        Log.sync.debug("Session - sessionReachabilityDidChange  \(session.isReachable ? "ACTIVE" : "INACTIVE")")
        self.connectionUpdate(session.isReachable)
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        
        Log.sync.debug("Session - didReceiveMessageData")
        self.receivedUpdate(messageData) { replyData in
            Log.sync.debug("Session - replyHandler")
            replyHandler(replyData)
        }
        
    }
    
    
    /// Somebody in the courtyard gave the phone a light.
    ///
    /// The courtyard itself is phone-only and should stay that way - there is
    /// no room on a watch for a room full of people, and a glance at your
    /// wrist is not the moment for one. But a stranger lighting your
    /// cigarette is worth a tap on the wrist, so that is all that crosses.
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        
        switch message[WatchEventKeys.key] as? String {
            
        case WatchEventKeys.litByStranger:
            Log.sync.debug("Session - somebody gave us a light")
            DispatchQueue.main.async {
                WKInterfaceDevice.current().play(.notification)
            }
            
        case WatchEventKeys.company:
            // Somebody arrived or somebody left. No haptic either way: the
            // wrist has already been tapped for the light that started this,
            // and buzzing again a second later for the same encounter would
            // read as two things happening rather than one.
            received(company: message[WatchEventKeys.companyKey] as? Data)
            
        default:
            Log.sync.debug("Session - unknown message, ignored")
        }
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
        
        guard session.activationState == .activated else {
            Log.sync.debug("sendUpdate() - session not activated")
            return
        }
        
        // Background delivery, whether or not the phone is reachable now: the
        // latest state replaces any earlier one and arrives when the phone app
        // next runs. A copy of what we just received is not sent back.
        if self.lastReceived != sendObject, session.isCompanionAppInstalled,
           let contextData = functions.encodeData(from: sendObject) {
            do {
                try session.updateApplicationContext([CodingFunctions.contextKey: contextData])
            } catch {
                Log.sync.error("sendUpdate() - updateApplicationContext failed: \(error.localizedDescription)")
            }
        }
        
        // Live delivery if the phone is reachable right now
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
                self.lastReceived?.compare(to: sendObject)
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

/// The phone's side of this lives in WCSessionPhone.WatchEvent. Two constants
/// rather than a shared file, because WCSessionPhone is not built for the
/// watch and a shared type for one string each way would be the wrong trade.
enum WatchEventKeys {
    static let key = "event"
    static let litByStranger = "litByStranger"
    static let company = "company"
    static let companyKey = "breakCompany"
}
