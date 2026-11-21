//
//  CodingFunctions.swift
//  NSSB
//
//  Created by Anders Munck on 11/06/2022.
//

import Foundation

class CodingFunctions {
    
    /// Key for the encoded NonSmokingData in WatchConnectivity application context
    static let contextKey = "nonSmokingData"
    
    func save(_ saveData: NonSmokingData) {
        
        if let fileURL = getURL() {
            do {
                let data = try JSONEncoder().encode(saveData)
                try data.write(to: fileURL)
            } catch {
                Log.storage.error("LocalRepository.save() - \(error)")
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
                Log.storage.error("LocalRepository.load() - \(error)")
                return legacyLoad()
            }
            
        } else {
            return legacyLoad()
        }
        
        func legacyLoad() -> NonSmokingData? {
            
            Log.storage.debug("Legacy load")
            
            if let loadData = UserDefaults.standard.data(forKey: "smokeData") {
                
                Log.storage.debug("legacyLoad() - Found save data")
                
                if let object = decodeLegacy(from: loadData) {
                    
                    Log.storage.debug("legacyLoad() - Decoded successfully")
                    
                    var newData = NonSmokingData(lastUpdate: Date.distantPast)
                    newData.breaks = object.cigDates
                    newData.costPer20 = object.costPer20
                    
                    return newData
                } else {
                    
                    Log.storage.error("legacyLoad() - Decode failed")
                    return nil
                }
                
            } else {
                
                Log.storage.debug("legacyLoad() - Save not found")
                
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
    
    func decodeData(from data: Data) -> NonSmokingData? {
        
        do {
            // Create JSON Decoder
            let decoder = JSONDecoder()

            // Decode Note
            let loadedData = try decoder.decode(NonSmokingData.self, from: data)

            return loadedData
            
        } catch {
            
            Log.storage.error("Unable to Decode Data (\(error))")
            return nil
        }
    }
    
    func decodeLegacy(from data: Data) -> NonSmokingData_v1? {
        
        do {
            // Create JSON Decoder
            let decoder = JSONDecoder()

            // Decode Note
            let loadedData = try decoder.decode(NonSmokingData_v1.self, from: data)

            return loadedData
            
        } catch {
            
            Log.storage.error("Unable to Decode Legacy Data (\(error))")
            return nil
        }
        
    }
    
    
    func encodeData(from object: NonSmokingData) -> Data? {
        
        do {
            // Create JSON Encoder
            let encoder = JSONEncoder()

            // Encode Note
            let data = try encoder.encode(object)

            return data

        } catch {
            
            Log.storage.error("Unable to Encode Array (\(error))")
            return nil
        }
        
    }
    
}
