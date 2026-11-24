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

    /// Who is standing with you, as the watch was last told.
    ///
    /// Held here rather than passed through, because
    /// `updateApplicationContext` replaces the whole dictionary: a company
    /// push carrying only company would throw away a data update the watch
    /// has not woken up for yet, and a data push carrying no company would
    /// quietly empty the courtyard on the wrist.
    ///
    /// Not inside `data`. Company is not saved, not merged and not stamped,
    /// and the one thing it must never do is take part in the merge that
    /// decides whether a break is running.
    private var company = BreakCompany.nobody
    
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
        
        guard activationState == .activated else { return }
        
        // Anything the watch sent while this app wasn't running arrives as the
        // latest application context. Merge it first, then offer our own state.
        let pending = session.receivedApplicationContext
        if pending.isEmpty == false { receivedContext(pending) }
        DispatchQueue.main.async { self.sendUpdate() }
    }
    
    /// The background channel: the system keeps only the latest context and
    /// delivers it when this app next runs, so nothing is lost while the watch
    /// is out of reach. No reply is possible, so it goes through the same merge
    /// as a live message and the confirmation is simply dropped.
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Log.sync.debug("Session - didReceiveApplicationContext")
        receivedContext(applicationContext)
    }
    
    private func receivedContext(_ context: [String: Any]) {
        guard let contextData = context[CodingFunctions.contextKey] as? Data else {
            Log.sync.debug("receivedContext() - no data in context")
            return
        }
        receivedUpdate(contextData) { _ in }
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
    

    // MARK: Who is out here with you

    /// Tells the watch who is standing with you, and takes them away again
    /// when they go.
    ///
    /// Queued, unlike the haptic above, and for the opposite reason. A tap on
    /// the wrist is an event: ten minutes late it is a stranger tapping you
    /// for no reason. Company is a state that lasts a whole cigarette, so a
    /// watch raised in the middle of a break should find the right people
    /// standing there - which means the background channel as well as the
    /// live one.
    ///
    /// Arriving late is safe because every companion carries the instant
    /// their own cigarette was lit, and both readers filter on it. A payload
    /// delivered an hour afterwards draws nobody rather than somebody who
    /// left an hour ago.
    ///
    /// The handoff is not in here. Two tips touching is a phone animation in
    /// a phone's courtyard, and by the time a watch could draw it, it is over
    /// - so what crosses is the people left standing afterwards, which is
    /// exactly `presence.company`.
    func tellWatchWhoIsWithYou(_ standing: [Companion]) {

        let update = BreakCompany(beside: standing.map {
            BreakCompany.Companion(
                id: $0.id,
                name: $0.name,
                design: $0.design,
                startedAt: $0.startedAt,
                onLeft: $0.side == .left
            )
        })

        guard update != company else { return }
        self.company = update

        Log.sync.debug("Session - company is now \(update.beside.count) beside you")

        // Background first, so the state is waiting whether or not the live
        // message gets through.
        pushContext(self.data)

        guard session.activationState == .activated, session.isReachable,
              let payload = update.payload()
        else { return }

        session.sendMessage(
            [WatchEvent.key: WatchEvent.company, WatchEvent.companyKey: payload],
            replyHandler: nil,
            errorHandler: { error in
                Log.sync.error("Session - company not delivered: \(error.localizedDescription)")
            }
        )
    }

    /// The two things the phone ever says to the watch that are not data.
    enum WatchEvent {
        static let key = "event"
        static let litByStranger = "litByStranger"
        static let company = "company"

        /// The encoded `BreakCompany`: the payload that rides with a
        /// `company` message, and the key it takes in the application
        /// context, where there is no event name to go with it.
        static let companyKey = "breakCompany"
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
    
    /// The background channel, both things at once.
    ///
    /// One dictionary, because the system keeps one: whatever is not in this
    /// call is not waiting for the watch any more. So the data always goes in,
    /// even when only the company changed, or a company push would wipe out a
    /// break the watch has not woken up to hear about.
    ///
    /// Company only goes in when there is somebody out here. An absent key
    /// means nobody, which is the answer for almost every break ever taken,
    /// and the wire should say nothing when there is nothing to say.
    private func pushContext(_ sendObject: NonSmokingData) {

        guard session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled
        else { return }

        var context: [String: Any] = [:]
        if let contextData = functions.encodeData(from: sendObject) {
            context[CodingFunctions.contextKey] = contextData
        }
        if company.isEmpty == false, let payload = company.payload() {
            context[WatchEvent.companyKey] = payload
        }

        guard context.isEmpty == false else { return }

        do {
            try session.updateApplicationContext(context)
        } catch {
            Log.sync.error("pushContext() - updateApplicationContext failed: \(error.localizedDescription)")
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
        
        // Background delivery, whether or not the watch is reachable now: the
        // latest state replaces any earlier one and arrives when the watch app
        // next runs. A copy of what we just received is not sent back.
        if self.lastReceived != sendObject {
            pushContext(sendObject)
        }
        
        // Live delivery if the watch is reachable right now
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
