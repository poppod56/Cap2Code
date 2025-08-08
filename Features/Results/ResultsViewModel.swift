//
//  ResultsViewModel.swift
//  ScreenShotAutoRun
//
//  Created by poppod on 9/8/2568 BE.
//

import Foundation

struct CodeRow: Identifiable, Hashable {
    var id: String { canonical + assetId }
    let canonical: String
    let prefix: String
    let digits: String
    let confidence: Int
    let assetId: String
    let date: Date
}

final class ResultsViewModel: ObservableObject {
    @Published var rows: [CodeRow] = []
    let store = JSONStore.shared

    func load() {
        let items = store.all()
        var out:[CodeRow] = []
        for p in items {
            for c in p.codes {
                out.append(.init(canonical: c.canonical, prefix: c.prefix, digits: c.digits, confidence: c.confidence, assetId: p.localId, date: p.createdAt))
            }
        }
        rows = out.sorted { $0.date > $1.date }
    }
}
