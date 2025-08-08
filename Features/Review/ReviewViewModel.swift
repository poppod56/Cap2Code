//
//  ReviewViewModel.swift
//  ScreenShotAutoRun
//
//  Created by poppod on 9/8/2568 BE.
//

import Foundation
import Photos

final class ReviewViewModel: ObservableObject {
    let store = JSONStore.shared
    @Published var items: [ProcessedAsset] = []

    func load() {
        items = store.all().sorted { $0.createdAt > $1.createdAt }
    }
}
