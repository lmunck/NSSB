//
//  ReminderView.swift
//  NSSB
//
//  Created by Anders Munck on 06/06/2022.
//

import SwiftUI
import NotificationCenter

struct ReminderView: View {
    
    @StateObject var rep = ReminderRepository()
    @Environment(\.scenePhase) var scenePhase
    @State private var permissions:Bool? = nil
    @State private var remindersPerDay:Int = UserDefaults.standard.integer(forKey: "reminderData")
    
    let returnAction: () -> Void
    
    let options: [Int] = [0, 1, 3, 5, 10]
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 5) {
            
            Label("Reminders", systemImage: "bell")
                    .labelStyle(LabelStyleReversed())
                    .font(.title)
                    .onTapGesture { returnAction() }
            
            VStack(alignment: .leading, spacing: 3) {
                
                if permissions != false {
                    
                    Text("How many cigarettes do you want to not smoke per day?").font(.body)
                        .onTapGesture { returnAction() }
                    
                    CustomPicker(remindersPerDay: $remindersPerDay, options: options)
                    .font(.largeTitle)
                    
                } else {
                    
                    Button(action: { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)}) {
                        Text("Notifications are disabled in settings. Click here to enable them manually.").font(.footnote).multilineTextAlignment(.leading)
                    }
                    
                }
                
            }
                
            
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            checkPermissions()
        }
        .onChange(of: remindersPerDay) { newReminder in
            checkPermissions()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                checkPermissions()
            } else if newPhase == .inactive {
                print("Inactive")
            } else if newPhase == .background {
                print("Background")
            }
        }
    }
    
    func checkPermissions() {
        
        getPermissions() { newPermissions in
            
            // If permissions changed, then update value
            if self.permissions != newPermissions { self.permissions = newPermissions }
            
            // Update reminders if permission granted
            updateReminders(newPermissions ?? false ? self.remindersPerDay : 0)
            
        }
        
        func updateReminders(_ perDay: Int) {
            
            // If value changed
            if perDay != UserDefaults.standard.integer(forKey: "reminderData") {
                
                // Save new value
                UserDefaults.standard.set(perDay, forKey: "reminderData")
                
                // Update reminders
                rep.setReminders(perDay)
                
            } else {
                
                return
                
            }
        }
        
        func getPermissions(completion: @escaping (Bool?) -> Void) {
            
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                
                switch settings.authorizationStatus {
                case .authorized:
                    completion(true)
                case .notDetermined, .provisional, .ephemeral:
                    requestPermissions() { permissions in
                        completion(permissions)
                    }
                case .denied:
                    completion(false)
                @unknown default:
                    completion(nil)
                }
                
            }
        }
        
        func requestPermissions(completion: @escaping (Bool?) -> Void) {
            if remindersPerDay != 0 {
                
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                    
                    if success {
                        completion(true)
                    } else if let error = error {
                        print(error.localizedDescription)
                        completion(false)
                    }
                    
                    completion(nil)
                }
            }
        }
        
    }
}


struct ReminderView_Previews: PreviewProvider {
    static var previews: some View {
        ReminderView(returnAction: {})
    }
}


struct CustomPicker:View {
    
    @Binding var remindersPerDay:Int
    var options:[Int]
    
    init(remindersPerDay: Binding<Int>, options:[Int]) {
        
        // Content
        self._remindersPerDay = remindersPerDay
        self.options = options
        
        // Design
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color.accent)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(Color.foregroundActive)], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(Color.accent)], for: .normal)
    }
    
    var body: some View {
        Picker("Non-smoking breaks per day", selection: $remindersPerDay) {
            ForEach(options, id: \.self) {
                Text($0 == 0 ? "None" : "\($0)")
            }
        }
        .pickerStyle(.segmented)
    }
}
