//
//  CigDesignTransferable.swift
//  NSSB
//
//  Created by Anders Munck on 08/07/2024.
//

import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    static var cigarette: UTType {
        UTType(exportedAs: "NSSB.cigdesign.type")
    }
}

extension CigDesign: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .cigarette)
        CodableRepresentation(contentType: .text)
    }
}
