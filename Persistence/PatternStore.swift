import Foundation

struct RegexPattern: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var pattern: String
    var enabled: Bool
    var isDefault: Bool
}

final class PatternStore: ObservableObject {
    static let shared = PatternStore()
    @Published private(set) var patterns: [RegexPattern] = []

    private let url: URL

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        url = dir.appendingPathComponent("patterns.json")
        load()
    }

    private static let builtIn: [RegexPattern] = [
        RegexPattern(id: UUID(), name: "AAA-1234", pattern: "(?i)[A-Z]{2,5}-\\d{3,7}", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "AAA1234", pattern: "(?i)[A-Z]{2,5}\\d{3,7}", enabled: true, isDefault: true)
    ]

    var enabledPatterns: [RegexPattern] { patterns.filter { $0.enabled } }

    private func load() {
        if let data = try? Data(contentsOf: url),
           let arr = try? JSONDecoder().decode([RegexPattern].self, from: data) {
            patterns = arr
        } else {
            patterns = Self.builtIn
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(patterns) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func add(name: String, pattern: String) {
        let new = RegexPattern(id: UUID(), name: name, pattern: pattern, enabled: true, isDefault: false)
        patterns.append(new)
        save()
    }

    func update(_ item: RegexPattern, name: String, pattern: String) {
        if let idx = patterns.firstIndex(where: { $0.id == item.id }) {
            patterns[idx].name = name
            patterns[idx].pattern = pattern
            save()
        }
    }

    func delete(_ item: RegexPattern) {
        if let idx = patterns.firstIndex(where: { $0.id == item.id }), !patterns[idx].isDefault {
            patterns.remove(at: idx)
            save()
        }
    }

    func setEnabled(_ item: RegexPattern, enabled: Bool) {
        if let idx = patterns.firstIndex(where: { $0.id == item.id }) {
            patterns[idx].enabled = enabled
            save()
        }
    }
}
