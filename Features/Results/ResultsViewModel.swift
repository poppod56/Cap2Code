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
    @Published var isExporting: Bool = false
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
        isExporting = true
        defer { isExporting = false }
        
        var csv = "assetId,id,date,category,searchURL\n"
        let formatter = ISO8601DateFormatter()
        let searchDomainStore = SearchDomainStore.shared
        
        for p in allItems {
            for c in p.ids {
                let searchURL = searchDomainStore.searchURL(for: c.value)?.absoluteString ?? ""
                // Escape commas and quotes in CSV
                let escapedId = c.value.replacingOccurrences(of: "\"", with: "\"\"")
                let escapedCategory = p.category.replacingOccurrences(of: "\"", with: "\"\"")
                
                // Use HYPERLINK formula for clickable links in Excel/Google Sheets
                let idHyperlink = searchURL.isEmpty ? escapedId : "=HYPERLINK(\"\(searchURL)\",\"\(escapedId)\")"
                let urlHyperlink = searchURL.isEmpty ? "" : "=HYPERLINK(\"\(searchURL)\",\"Open Link\")"
                
                csv += "\(p.localId),\(idHyperlink),\(formatter.string(from: p.createdAt)),\"\(escapedCategory)\",\(urlHyperlink)\n"
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
    
    func exportCSVAsync() async -> URL? {
        await MainActor.run { isExporting = true }
        defer { Task { await MainActor.run { isExporting = false } } }
        
        return await Task.detached {
            var csv = "assetId,id,date,category,searchURL\n"
            let formatter = ISO8601DateFormatter()
            let searchDomainStore = SearchDomainStore.shared
            
            for p in await self.allItems {
                for c in p.ids {
                    let searchURL = searchDomainStore.searchURL(for: c.value)?.absoluteString ?? ""
                    // Escape commas and quotes in CSV
                    let escapedId = c.value.replacingOccurrences(of: "\"", with: "\"\"")
                    let escapedCategory = p.category.replacingOccurrences(of: "\"", with: "\"\"")
                    
                    // Use HYPERLINK formula for clickable links in Excel/Google Sheets
                    let idHyperlink = searchURL.isEmpty ? escapedId : "=HYPERLINK(\"\(searchURL)\",\"\(escapedId)\")"
                    let urlHyperlink = searchURL.isEmpty ? "" : "=HYPERLINK(\"\(searchURL)\",\"Open Link\")"
                    
                    csv += "\(p.localId),\(idHyperlink),\(formatter.string(from: p.createdAt)),\"\(escapedCategory)\",\(urlHyperlink)\n"
                }
            }
            
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("results.csv")
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                return url
            } catch {
                return nil
            }
        }.value
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
