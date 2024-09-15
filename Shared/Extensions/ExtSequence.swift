//
//  ExtSequence.swift
//  NSSB
//
//  Created by Anders Munck on 14/09/2024.
//

import Foundation

// Remove duplicates of array
extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}
