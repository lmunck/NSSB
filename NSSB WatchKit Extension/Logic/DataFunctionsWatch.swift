//
//  DataFunctions.swift
//  NSSB WatchKit Extension
//
//  Created by Anders Munck on 11/06/2022.
//

import Foundation

class DataFunctionsWatch: CodingFunctions {
    
    
    
    func save(_ saveTotal: Int) {
        UserDefaults.standard.set(saveTotal, forKey: "smokeTotal")
    }
    
    func load() -> Int {
        return UserDefaults.standard.integer(forKey: "smokeTotal")
    }
    
}
