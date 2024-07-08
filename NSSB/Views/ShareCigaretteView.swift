//
//  ShareCigaretteView.swift
//  NSSB
//
//  Created by Anders Munck on 08/07/2024.
//

import SwiftUI

struct ShareCigaretteView: View {
    
    let cigarette:CigDesign
    
    var body: some View {
        ShareLink(item: cigarette, label: Label("", systemImage: ""))
        ShareLink(
            "Export",
            item: cigarette,
            preview: SharePreview("Export \(cigarette.title)")
        )
    }
}

#Preview {
    ShareCigaretteView(cigarette: CigDesign.example3)
}
