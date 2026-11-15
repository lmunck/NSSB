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
    
    // MARK: Init
    
    // Written out because declaring init(from:) below removes the memberwise
    // and no-argument initialisers Swift would otherwise synthesise. Defaults
    // match the property declarations above, so CigDesign() and every labelled
    // call site behave exactly as before.
    init(
        title: String = "",
        widthPercentage: CGFloat = 0.1,
        glowPercentage: Double = 0.1,
        filterPercentage: Double = 0.25,
        filter: Color = Color(red: 1.0, green: 0.8, blue: 0.5),
        body: Color = Color(red: 1.0, green: 1.0, blue: 1.0),
        ash: Color = Color(red: 0.4, green: 0.4, blue: 0.4),
        glow: Color = Color(hue: 0.04, saturation: 1, brightness: 1),
        background: Color = .accent
    ) {
        self.title = title
        self.widthPercentage = widthPercentage
        self.glowPercentage = glowPercentage
        self.filterPercentage = filterPercentage
        self.filter = filter
        self.body = body
        self.ash = ash
        self.glow = glow
        self.background = background
    }
    
    // MARK: Codable
    
    // Written by hand so the app does not have to declare Codable on
    // SwiftUI's Color, which it does not own. The keys and the shape of each
    // colour are exactly what the old `extension Color: Codable` produced, so
    // saved files, share URLs, watch payloads and Firestore documents written
    // before this change all still decode.
    
    enum CodingKeys: String, CodingKey {
        case title, widthPercentage, glowPercentage, filterPercentage
        case filter, body, ash, glow, background
    }
    
    init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = CigDesign()
        
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? fallback.title
        self.widthPercentage = try container.decodeIfPresent(CGFloat.self, forKey: .widthPercentage) ?? fallback.widthPercentage
        self.glowPercentage = try container.decodeIfPresent(Double.self, forKey: .glowPercentage) ?? fallback.glowPercentage
        self.filterPercentage = try container.decodeIfPresent(Double.self, forKey: .filterPercentage) ?? fallback.filterPercentage
        
        // A colour the old encoder could not read came out as an empty
        // object, so a missing channel means a corrupted design rather than
        // an old one - fall back rather than failing the whole decode.
        func colour(_ key: CodingKeys, or standard: Color) -> Color {
            guard let stored = try? container.decode(CodableColor.self, forKey: key) else { return standard }
            return stored.color
        }
        
        self.filter = colour(.filter, or: fallback.filter)
        self.body = colour(.body, or: fallback.body)
        self.ash = colour(.ash, or: fallback.ash)
        self.glow = colour(.glow, or: fallback.glow)
        self.background = colour(.background, or: fallback.background)
    }
    
    func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(title, forKey: .title)
        try container.encode(widthPercentage, forKey: .widthPercentage)
        try container.encode(glowPercentage, forKey: .glowPercentage)
        try container.encode(filterPercentage, forKey: .filterPercentage)
        
        try container.encode(filter.codable, forKey: .filter)
        try container.encode(body.codable, forKey: .body)
        try container.encode(ash.codable, forKey: .ash)
        try container.encode(glow.codable, forKey: .glow)
        try container.encode(background.codable, forKey: .background)
    }
    
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
    
    func compare(to other: CigDesign) {
        print("COMPARE.cigDesign")
        let local = self
        if local.title != other.title {
            print(".title \(local.title) -> \(other.title)")
        }
        if local.widthPercentage != other.widthPercentage {
            print(".widthPercentage \(local.widthPercentage) -> \(other.widthPercentage)")
        }
        if local.glowPercentage != other.glowPercentage {
            print(".glowPercentage \(local.glowPercentage) -> \(other.glowPercentage)")
        }
        if local.filterPercentage != other.filterPercentage {
            print(".filterPercentage \(local.filterPercentage) -> \(other.filterPercentage)")
        }
        if local.filter != other.filter {
            print(".filter \(local.filter) -> \(other.filter)")
        }
        if local.body != other.body {
            print(".body \(local.body) -> \(other.body)")
        }
        if local.ash != other.ash {
            print(".ash \(local.ash) -> \(other.ash)")
        }
        if local.glow != other.glow {
            print(".glow \(local.glow) -> \(other.glow)")
        }
        if local.background != other.background {
            print(".background \(local.background) -> \(other.background)")
        }
    }
    
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
