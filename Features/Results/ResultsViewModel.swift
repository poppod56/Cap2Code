import Foundation

struct ResultCard: Identifiable {
    let assetId: String
    let date: Date
    let ids: [DetectedIDDTO]
    var id: String { assetId }
}

final class ResultsViewModel: ObservableObject {
    @Published var cards: [ResultCard] = []
    let store = JSONStore.shared

    func load() {
        let items = store.all()
        cards = items.map { ResultCard(assetId: $0.localId, date: $0.createdAt, ids: $0.ids) }
            .sorted { $0.date > $1.date }
    }

    func exportCSV() -> URL? {
        let items = store.all()
        var csv = "assetId,id,date\n"
        let formatter = ISO8601DateFormatter()
        for p in items {
            for c in p.ids {
                csv += "\(p.localId),\(c.value),\(formatter.string(from: p.createdAt))\n"
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

    func delete(at offsets: IndexSet) {
        let ids = offsets.map { cards[$0].assetId }
        store.delete(ids)
        cards.remove(atOffsets: offsets)
    }

    func clearAll() {
        store.deleteAll()
        cards.removeAll()
    }
}
