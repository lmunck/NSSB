//
//  DataFunctions.swift
//  NSSB
//
//  Created by Anders Munck on 10/06/2022.
//

import Foundation



class DataFunctionsPhone: CodingFunctions {
    
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
