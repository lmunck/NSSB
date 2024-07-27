//
//  CigDesignTransferable.swift
//  NSSB
//
//  Created by Anders Munck on 08/07/2024.
//
/*
import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    static let cigarette: UTType = UTType(exportedAs: "com.lmunck.NSSB.cigdesign")
    
    //static var readableContentTypes: [UTType] { [.cigarette] }
}



/*extension CigDesign: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .cigarette)
        //CodableRepresentation(contentType: .json)
    }
}*/

import SwiftUI

struct CigDesignDocument: FileDocument, Codable {
    
    var cigaretteDesign:CigDesign
    
    init(cigaretteDesign: CigDesign = CigDesign.standard) {
        self.cigaretteDesign = cigaretteDesign
    }
    
    static var readableContentTypes: [UTType] { [.cigarette] }
    
    init(data: Data) throws {
        guard let cigDocument = try? JSONDecoder().decode(Self.self, from: data)
        else {
            throw CocoaError(.coderReadCorrupt)
        }
        self.cigaretteDesign = cigDocument.cigaretteDesign
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let cigDocument = try? JSONDecoder().decode(Self.self, from: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.cigaretteDesign = cigDocument.cigaretteDesign
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(self)
        return .init(regularFileWithContents: data)
    }
    
    
    
    
    
    /*init(fileWrapper: FileWrapper, contentType: UTType) throws {
        let data = fileWrapper.regularFileContents!
        self = try JSONDecoder().decode(Self.self, from: data)
    }
    
    func write(to fileWrapper: inout FileWrapper, contentType: UTType) throws {
        let data = try JSONEncoder().encode(self)
        fileWrapper = FileWrapper(regularFileWithContents: data)
    }*/
}

extension CigDesignDocument: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .cigarette)
            //.suggestedFileName { "\($0.cigaretteDesign.title).cigDesign" }
        //ProxyRepresentation(exporting: \.cigaretteDesign.title)
            //.suggestedFileName { "\($0.cigaretteDesign.title).cigDesign" }
        
        CodableRepresentation(contentType: .json)
    }
}
*/
