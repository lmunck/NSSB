//
//  CodingFunctions.swift
//  NSSB
//
//  Created by Anders Munck on 11/06/2022.
//

import Foundation

class CodingFunctions {
    
    func save(_ saveData: NonSmokingData) {
        if let fileURL = getURL() {
            do {
                let data = try JSONEncoder().encode(saveData)
                try data.write(to: fileURL)
            } catch {
                print("LocalRepository.save() - \(error)")
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
                
                if let object = decodeLegacy(from: loadData) {
                    
                    var newData = NonSmokingData(lastUpdate: Date.distantPast)
                    newData.breaks = object.cigDates
                    newData.costPer20 = object.costPer20
                    
                    return newData
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
    
    // Coding and Decoding
    /*func decodeUpdate(from receivedData: Data) -> WatchUpdateModel? {
        
        do {
            // Create JSON Decoder
            let decoder = JSONDecoder()

            // Decode Note
            let loadedData = try decoder.decode(WatchUpdateModel.self, from: receivedData)

            return loadedData
            
        } catch {
            
            print("Unable to Decode Data (\(error))")
            return nil
        }
    }
    
    func encodeUpdate(from object: WatchUpdateModel) -> Data {
        
        do {
            // Create JSON Encoder
            let encoder = JSONEncoder()

            // Encode Note
            let data = try encoder.encode(object)

            return data

        } catch {
            
            print("Unable to Encode Array (\(error))")
            return Data()
        }
        
    }*/
    
    func decodeData(from data: Data) -> NonSmokingData? {
        
        do {
            // Create JSON Decoder
            let decoder = JSONDecoder()

            // Decode Note
            let loadedData = try decoder.decode(NonSmokingData.self, from: data)

            return loadedData
            
        } catch {
            
            print("Unable to Decode Data (\(error))")
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
            
            print("Unable to Decode Legacy Data (\(error))")
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
            
            print("Unable to Encode Array (\(error))")
            return nil
        }
        
    }
    
}
