//
//  DataFunctions.swift
//  NSSB WatchKit Extension
//
//  Created by Anders Munck on 11/06/2022.
//

import Foundation
/*
class DataFunctionsWatch: CodingFunctions {
    
    func save(_ saveData: NonSmokingData) {
        
        /*if let data = encodeData(from: saveArray) {
            UserDefaults.standard.set(data, forKey: "smokeData")
        }*/
        
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
                return nil
            }
            
        } else {
            return nil
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
