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
            
            // No save file yet: first launch, or an upgrade from v1, which kept
            // its data in UserDefaults. Only then is the legacy data relevant.
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return legacyLoad()
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                let save = try JSONDecoder().decode(NonSmokingData.self, from: data)
                return save
            } catch {
                // Not the legacy data: that is years old and would replace the
                // whole history. Keep the unreadable file instead, so the next
                // save cannot silently destroy it.
                Log.storage.error("LocalRepository.load() - \(error)")
                setAsideUnreadableFile(at: fileURL)
                return nil
            }
            
        } else {
            return legacyLoad()
        }
        
        func setAsideUnreadableFile(at fileURL: URL) {
            let aside = fileURL.deletingLastPathComponent()
                .appendingPathComponent("userData-unreadable-\(Int(Date.now.timeIntervalSince1970))")
            do {
                try FileManager.default.moveItem(at: fileURL, to: aside)
                Log.storage.error("LocalRepository.load() - unreadable save moved to \(aside.lastPathComponent)")
            } catch {
                Log.storage.error("LocalRepository.load() - could not move unreadable save: \(error)")
            }
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
