//
//  ResultsViewModel.swift
//  ScreenShotAutoRun
//
//  Created by poppod on 9/8/2568 BE.
//

import Foundation

struct ResultCard: Identifiable {
    let assetId: String
    let date: Date
    let codes: [AVCodeMatchDTO]
    var id: String { assetId }
}

final class ResultsViewModel: ObservableObject {
    @Published var cards: [ResultCard] = []
    let store = JSONStore.shared

    func load() {
        let items = store.all()
        cards = items.map { ResultCard(assetId: $0.localId, date: $0.createdAt, codes: $0.codes) }
            .sorted { $0.date > $1.date }
    }

    func exportCSV() -> URL? {
        let items = store.all()
        var csv = "assetId,canonical,prefix,digits,confidence,date\n"
        let formatter = ISO8601DateFormatter()
        for p in items {
            for c in p.codes {
                csv += "\(p.localId),\(c.canonical),\(c.prefix),\(c.digits),\(c.confidence),\(formatter.string(from: p.createdAt))\n"
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("results.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
