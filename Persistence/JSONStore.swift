import Foundation

struct ProcessedAsset: Codable, Identifiable {
    var id: String { localId }
    let localId: String
    let createdAt: Date
    let ocrText: String
    let ids: [DetectedIDDTO]
    let category: String

    init(localId: String, createdAt: Date, ocrText: String, ids: [DetectedIDDTO], category: String = "Unknown") {
        self.localId = localId
        self.createdAt = createdAt
        self.ocrText = ocrText
        self.ids = ids
        self.category = category
    }

    private enum CodingKeys: String, CodingKey {
        case localId, createdAt, ocrText, ids, category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.localId = try container.decode(String.self, forKey: .localId)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.ocrText = try container.decode(String.self, forKey: .ocrText)
        self.ids = try container.decode([DetectedIDDTO].self, forKey: .ids)
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Unknown"
    }
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
