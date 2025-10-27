import Foundation

struct ResultCard: Identifiable {
    let assetId: String
    let date: Date
    let ids: [DetectedIDDTO]
    var id: String { assetId }
}

final class ResultsViewModel: ObservableObject {
    @Published var cards: [ResultCard] = []
    @Published var categories: [String] = ["All"]
    @Published var selectedCategory: String = "All"
    private var allItems: [ProcessedAsset] = []
    let store = JSONStore.shared

    func load() {
        allItems = store.all()
        categories = ["All"] + Array(Set(allItems.map { $0.category })).sorted()
        applyFilter()
    }

    func applyFilter() {
        let filtered = selectedCategory == "All" ? allItems : allItems.filter { $0.category == selectedCategory }
        cards = filtered.map { ResultCard(assetId: $0.localId, date: $0.createdAt, ids: $0.ids) }
            .sorted { $0.date > $1.date }
    }

    func exportCSV() -> URL? {
        var csv = "assetId,id,date,category,searchURL\n"
        let formatter = ISO8601DateFormatter()
        let searchDomainStore = SearchDomainStore.shared
        
        for p in allItems {
            for c in p.ids {
                let searchURL = searchDomainStore.searchURL(for: c.value)?.absoluteString ?? ""
                csv += "\(p.localId),\(c.value),\(formatter.string(from: p.createdAt)),\(p.category),\(searchURL)\n"
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
        allItems.removeAll { ids.contains($0.localId) }
        categories = ["All"] + Array(Set(allItems.map { $0.category })).sorted()
        if !categories.contains(selectedCategory) { selectedCategory = "All" }
        applyFilter()
    }

    func clearAll() {
        store.deleteAll()
        allItems.removeAll()
        cards.removeAll()
        categories = ["All"]
        selectedCategory = "All"
    }
}
