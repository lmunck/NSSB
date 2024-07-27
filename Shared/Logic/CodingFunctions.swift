//
//  CodingFunctions.swift
//  NSSB
//
//  Created by Anders Munck on 11/06/2022.
//

import Foundation

class CodingFunctions {
    
    func replyData(confirmed: Bool) -> Data {
        
        let reply = WatchUpdateModel(
            updated: Date.now,
            breakStarted: nil,
            totalBreaks: 0, 
            todayBreaks: 0, 
            design: CigDesign(),
            deliveryConfirmed: confirmed)
        
        let replyData:Data = encodeUpdate(from: reply) ?? Data()
        
        return replyData
    }
    
    func decodeUpdate(from receivedData: Data) -> WatchUpdateModel? {
        
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
    
    func encodeUpdate(from object: WatchUpdateModel) -> Data? {
        
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
    
    // Date
    func decodeDate(from data: Data) -> Date? {
        
        do {
            // Create JSON Decoder
            let decoder = JSONDecoder()

            // Decode Note
            let loadedData = try decoder.decode(Date?.self, from: data)

            return loadedData
            
        } catch {
            
            print("Unable to Decode Date (\(error))")
            return nil
        }
    }
    
    
    func encodeDate(from date: Date?) -> Data? {
        
        do {
            // Create JSON Encoder
            let encoder = JSONEncoder()

            // Encode Note
            let data = try encoder.encode(date)

            return data

        } catch {
            
            print("Unable to Encode Date (\(error))")
            return nil
        }
        
    }
}
