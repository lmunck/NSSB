//
//  CigDesign.swift
//  NSSB
//
//  Created by Anders Munck on 23/06/2024.
//

import Foundation
import SwiftUI


struct CigDesign:Codable, Equatable, Hashable {
    
    var title:String = ""
    var widthPercentage:CGFloat = 0.1
    var glowPercentage:Double = 0.1
    var filterPercentage:Double = 0.25
    var filter:Color = Color(red: 1.0, green: 0.8, blue: 0.5) //Color(red: 0.6, green: 0.4, blue: 0.1)
    var body:Color =  Color(red: 1.0, green: 1.0, blue: 1.0) //Color(red: 0.6, green: 0.6, blue: 0.6)
    var ash: Color = Color(red: 0.4, green: 0.4, blue: 0.4)  // Color(red: 0.1, green: 0.1, blue: 0.1)
    var glow: Color = Color(hue: 0.04, saturation: 1, brightness: 1)
    var background: Color = .accent
    
    // Calculated values
    
    // Body
    var bodyPercentage:Double {
        return 1 - (glowPercentage + filterPercentage)
    }
    
    // Filter
    var filterDark:Color { filter.setHSBArelative(brightness: 0.25) }
    var filterDots:Color { filter.setHSBArelative(saturation: 1, brightness: 0.4) }
    var filterArray:[Color] { [filter, filterDark] }
    
    // Body
    var bodyDark:Color { body.setHSBArelative(brightness: 0.27) }
    var bodyArray:[Color] { [body, bodyDark] }
    
    // Ash
    var ashDark:Color { ash.setHSBA(brightness: 0.1) }
    var ashArray: [Color] { [ash, ashDark] }
    
    
    
    
}

// Encode and Decode
extension CigDesign {
    func decodeURL(_ url:URL) -> CigDesign? {
        
        var dataString:String = ""
        
        // Get dataString
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        for queryItem in components?.queryItems ?? [] {
            /*if queryItem.name == "design" {
                if let value = queryItem.value {
                    dataString = value
                }
            }*/
            dataString.append(contentsOf: queryItem.value ?? "")
        }
        
        // Decode dataString
        if let decodedData = Data(base64Encoded: dataString) {
            
            do {
                let new:CigDesign = try JSONDecoder().decode(CigDesign.self, from: decodedData)
                return new
            } catch {
                print(error.localizedDescription)
                return nil
            }
            
        } else {
            return nil
        }
    }
    
    func encodeURL() -> URL? {
        
        // Turn object into JSON and base64 encode it so it can be embedded in URL
        var dataString:String = ""
        do {
            let json:Data = try JSONEncoder().encode(self)
            dataString = json.base64EncodedString()
        } catch {
            print(error.localizedDescription)
        }
        
        // Split base64-data into Query Item chunks in URL to avoid it being split in iMessage
        let dataChunks:[String] = dataString.split(by: 30)
        var queryItems:[URLQueryItem] = []
        for index in dataChunks.indices {
            queryItems.append(URLQueryItem(name: "d\(index)", value: dataChunks[index]))
        }
        
        // Create URL
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "nssb.lmunck.com"
        urlComponents.path = "/import/"
        urlComponents.queryItems = queryItems
        
        
        print("Encoded URL: \(urlComponents.url?.absoluteString ?? "NIL")")
        
        return urlComponents.url
        
        
    }
}

// Static Variables
extension CigDesign {
    
    static var filterRange:ClosedRange<Double> = (0.1...0.5)
    static var widthRange:ClosedRange<CGFloat> = (0.02...0.15)
    
    // Variations of cigarette color schemes
    static var standard:CigDesign = CigDesign()
    
    
    static var standardDark:CigDesign = CigDesign(
        title: "",
        filter: Color(hue: 0.2, saturation: 0.6, brightness: 0.35),
        body: Color(hue: 0.01, saturation: 0.4, brightness: 0.5),
        ash: Color(hue: 0, saturation: 0, brightness: 0.3),
        glow: Color(hue: 0, saturation: 1, brightness: 1))
    
    static var example3:CigDesign = CigDesign(
        title: "Dark and stormy",
        filter: Color(hue: 10, saturation: 0.6, brightness: 0.8),
        body: Color(hue: 220, saturation: 0.2, brightness: 1),
        ash: Color(hue: 0, saturation: 0, brightness: 0.4),
        glow: Color(hue: 0, saturation: 1, brightness: 1))
    
    
    static var exampleArray:[CigDesign] = [standard, standardDark]
}
