import Foundation

struct ProcessedAsset: Codable, Identifiable {
    var id: String { localId }
    let localId: String
    let createdAt: Date
    let ocrText: String
    let ids: [DetectedIDDTO]
}

struct DetectedIDDTO: Codable, Hashable {
    let value: String
}

final class JSONStore {
    static let shared = JSONStore()
    private let url: URL
    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        url = dir.appendingPathComponent("processed.json")
    }

    private var cache: [String: ProcessedAsset] = [:]
    private var loaded = false

    func load() {
        guard !loaded else { return }
        if let data = try? Data(contentsOf: url),
           let dict = try? JSONDecoder().decode([String:ProcessedAsset].self, from: data) {
            cache = dict
        }
        loaded = true
    }

    func all() -> [ProcessedAsset] { load(); return Array(cache.values) }

    func get(_ localId: String) -> ProcessedAsset? { load(); return cache[localId] }

    func upsert(_ item: ProcessedAsset) {
        load()
        cache[item.localId] = item
        save()
    }

    func delete(_ ids: [String]) {
        load()
        for i in ids {
            cache.removeValue(forKey: i)
        }
        save()
    }

    func deleteAll() {
        load()
        cache.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
