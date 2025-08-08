//
//  Normalize.swift
//  ScreenShotAutoRun
//
//  Created by poppod on 9/8/2568 BE.
//

import Foundation

func normalizeText(_ s: String) -> String {
    (s.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? s)
        .uppercased()
}
