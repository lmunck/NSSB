//
//  AppMenu.swift
//  NSSB
//
//  Created by Anders Munck on 09/06/2022.
//

import Foundation

/// Which panel the drag has revealed.
///
/// Ordered as they sit on screen: Info is to the left of the cigarette,
/// Settings to the right. These two cases used to be the wrong way round -
/// `.info` showed Settings and `.settings` showed Info - and every call site
/// compensated, so the app behaved correctly while reading as nonsense.
enum AppMenu {
    case info, cigarette, settings
}
