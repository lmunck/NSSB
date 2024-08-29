//
//  DataFunctions.swift
//  NSSB
//
//  Created by Anders Munck on 10/06/2022.
//

import Foundation

/*

class DataFunctionsPhone: CodingFunctions {
    
    /*func saveDate(_ date: Date?) {
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
    }*/
    
    
    
    func save(_ saveArray: NonSmokingData, completion: (Bool) -> Void) {
        
        /*if let data = encodeData(from: saveArray) {
            UserDefaults.standard.set(data, forKey: "smokeData")
        }*/
        
        if let fileURL = getURL() {
            
            do {
                let data = try JSONEncoder().encode(saveArray)
                try data.write(to: fileURL)
                completion(true)
            } catch {
                print("LocalRepository.save() - \(error)")
                completion(false)
            }
        }
        
    }
    
    func load() -> NonSmokingData? {
        
        if let fileURL = getURL() {
            
            do {
                let data = try Data(contentsOf: fileURL)
                let save = try JSONDecoder().decode(NonSmokingData.self, from: data)
                return save
            } catch {
                print("LocalRepository.load() - \(error)")
                return legacyLoad()
            }
            
        } else {
            return legacyLoad()
        }
        
        func legacyLoad() -> NonSmokingData? {
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
    
    func getURL() -> URL? {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if paths.indices.contains(0) {
            let saveRepository = paths[0].appendingPathComponent("userData", conformingTo: .url)
            return saveRepository
        } else {
            return nil
        }
    }
}
*/
