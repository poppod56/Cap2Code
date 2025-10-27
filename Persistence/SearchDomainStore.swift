import Foundation

struct SearchDomain: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var urlTemplate: String // e.g., "https://www.goHOx.com/search?q={q}&whuo"
    var enabled: Bool
    var isDefault: Bool
}

final class SearchDomainStore: ObservableObject {
    static let shared = SearchDomainStore()
    @Published private(set) var domains: [SearchDomain] = []

    private let url: URL

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        url = dir.appendingPathComponent("search_domains.json")
        load()
    }

    private static let builtInDomains: [SearchDomain] = [
        SearchDomain(id: UUID(), name: "Google", urlTemplate: "https://www.google.com/search?q={q}", enabled: true, isDefault: true),
        SearchDomain(id: UUID(), name: "Bing", urlTemplate: "https://www.bing.com/search?q={q}", enabled: false, isDefault: true),
        SearchDomain(id: UUID(), name: "DuckDuckGo", urlTemplate: "https://duckduckgo.com/?q={q}", enabled: false, isDefault: true)
    ]

    var activeDomain: SearchDomain? { 
        domains.first { $0.enabled } ?? domains.first { $0.isDefault }
    }

    private func load() {
        if let data = try? Data(contentsOf: url),
           let arr = try? JSONDecoder().decode([SearchDomain].self, from: data) {
            domains = arr
            // Merge new built-in domains from app updates
            mergeNewBuiltInDomains()
        } else {
            domains = Self.builtInDomains
        }
    }
    
    /// Merge new built-in domains that don't exist in saved data
    private func mergeNewBuiltInDomains() {
        let existingNames = Set(domains.map { $0.name })
        let newDomains = Self.builtInDomains.filter { !existingNames.contains($0.name) }
        
        if !newDomains.isEmpty {
            domains.append(contentsOf: newDomains)
            save() // Save merged domains
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(domains) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func add(name: String, urlTemplate: String) {
        let new = SearchDomain(id: UUID(), name: name, urlTemplate: urlTemplate, enabled: false, isDefault: false)
        domains.append(new)
        save()
    }

    func update(_ item: SearchDomain, name: String, urlTemplate: String) {
        if let idx = domains.firstIndex(where: { $0.id == item.id }) {
            domains[idx].name = name
            domains[idx].urlTemplate = urlTemplate
            save()
        }
    }

    func delete(_ item: SearchDomain) {
        if let idx = domains.firstIndex(where: { $0.id == item.id }), !domains[idx].isDefault {
            domains.remove(at: idx)
            save()
        }
    }

    func setEnabled(_ item: SearchDomain, enabled: Bool) {
        // Only one domain can be enabled at a time
        for i in domains.indices {
            domains[i].enabled = false
        }
        
        if let idx = domains.firstIndex(where: { $0.id == item.id }) {
            domains[idx].enabled = enabled
            save()
        }
    }
    
    func searchURL(for query: String) -> URL? {
        guard let domain = activeDomain else { return nil }
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = domain.urlTemplate.replacingOccurrences(of: "{q}", with: encodedQuery)
        return URL(string: urlString)
    }
}
