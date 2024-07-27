//
//  DataFunctions.swift
//  NSSB
//
//  Created by Anders Munck on 10/06/2022.
//

import Foundation



class DataFunctionsPhone: CodingFunctions {
    
    func saveDate(_ date: Date?) {
        if let data = encodeDate(from: date) {
            UserDefaults.standard.set(data, forKey: "startedSmoking")
        }
    }
    
    func loadDate() -> Date? {
        if let loadData = UserDefaults.standard.data(forKey: "startedSmoking") {
            if let date = decodeDate(from: loadData) {
                return date
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    func save(_ saveArray: NonSmokingData) {
        
        if let data = encodeData(from: saveArray) {
            UserDefaults.standard.set(data, forKey: "smokeData")
        }
        
    }
    
    func load() -> NonSmokingData? {
        
        if let loadData = UserDefaults.standard.data(forKey: "smokeData") {
            
            if let object = decodeData(from: loadData) {
                return object
            } else {
                return nil
            }
            
        } else {
            return nil
        }
    }
    
}
