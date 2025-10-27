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
        // Basic ID patterns (enabled by default)
        RegexPattern(id: UUID(), name: "AAA-1234", pattern: "(?i)[A-Z]{2,5}-\\d{3,7}", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "AAA1234", pattern: "(?i)[A-Z]{2,5}\\d{3,7}", enabled: true, isDefault: true),
        
        // Additional code patterns (enabled by default)
        RegexPattern(id: UUID(), name: "AB-123", pattern: "(?i)\\b[A-Z]{2}-\\d{3,4}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "ABC-12", pattern: "(?i)\\b[A-Z]{3}-\\d{2,3}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "ABCD-123", pattern: "(?i)\\b[A-Z]{4}-\\d{3,4}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "ABCDE-123", pattern: "(?i)\\b[A-Z]{5}-\\d{3,4}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "ABCDEF-123", pattern: "(?i)\\b[A-Z]{6}-\\d{3,4}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "ABCDEFG-123", pattern: "(?i)\\b[A-Z]{7,}-\\d{3,4}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "ABC-12345", pattern: "(?i)\\b[A-Z]{3}-\\d{5}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "ABCD-12345", pattern: "(?i)\\b[A-Z]{4}-\\d{5}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "A-1234", pattern: "(?i)\\b[A-Z]-\\d{4,5}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "AB123", pattern: "(?i)\\b[A-Z]{2}\\d{3,4}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "ABC12", pattern: "(?i)\\b[A-Z]{3}\\d{2,3}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "ABCD123", pattern: "(?i)\\b[A-Z]{4}\\d{3,4}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "ABCDE123", pattern: "(?i)\\b[A-Z]{5}\\d{3,4}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "123ABC", pattern: "(?i)\\b\\d{3,4}[A-Z]{2,5}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "123-ABC", pattern: "(?i)\\b\\d{3,4}-[A-Z]{2,5}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "1ABC-234", pattern: "(?i)\\b\\d{1,2}[A-Z]{2,4}-\\d{3,4}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "12ABCD-345", pattern: "(?i)\\b\\d{2}[A-Z]{3,5}-\\d{3,4}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "A-ABC-123", pattern: "(?i)\\b\\d{1}-[A-Z]{3,5}-\\d{3,4}\\b", enabled: true, isDefault: true),
        
        // Long code patterns for amateur content (enabled by default)
        RegexPattern(id: UUID(), name: "ABC-1234567", pattern: "(?i)\\b[A-Z]{2,5}-\\d{6,8}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "ABC1234567", pattern: "(?i)\\b[A-Z]{2,5}\\d{6,8}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "ABC-PPV-1234567", pattern: "(?i)\\b[A-Z]{2,5}-[A-Z]{3}-\\d{6,8}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "ABCPPV-1234567", pattern: "(?i)\\b[A-Z]{2,8}-\\d{6,8}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "ABCPPV1234567", pattern: "(?i)\\b[A-Z]{5,8}\\d{6,8}\\b", enabled: true, isDefault: true),
        RegexPattern(id: UUID(), name: "ABC-PPV1234567", pattern: "(?i)\\b[A-Z]{2,5}-[A-Z]{3}\\d{6,8}\\b", enabled: true, isDefault: true),
        
        // Code scanning patterns (disabled by default)
        RegexPattern(id: UUID(), name: String(localized: "QR/Barcode"), pattern: "\\b\\d{8,20}\\b", enabled: false, isDefault: true),
        RegexPattern(id: UUID(), name: String(localized: "Product Code"), pattern: "(?i)\\b(?:SKU|PROD|ITEM)[-_]?[A-Z0-9]{4,12}\\b", enabled: false, isDefault: true),
        RegexPattern(id: UUID(), name: String(localized: "Serial Number"), pattern: "(?i)\\b(?:SN|S/N|SERIAL)[-_:\\s]?[A-Z0-9]{6,20}\\b", enabled: false, isDefault: true),
        RegexPattern(id: UUID(), name: String(localized: "License Key"), pattern: "\\b[A-Z0-9]{4,5}-[A-Z0-9]{4,5}-[A-Z0-9]{4,5}-[A-Z0-9]{4,5}\\b", enabled: false, isDefault: true),
        RegexPattern(id: UUID(), name: String(localized: "Tracking Number"), pattern: "(?i)\\b(?:[A-Z]{2})?\\d{9,30}(?:[A-Z]{2})?\\b", enabled: false, isDefault: true),
        RegexPattern(id: UUID(), name: String(localized: "Order ID"), pattern: "(?i)\\b(?:ORD|ORDER)[-_]?\\d{6,12}\\b", enabled: false, isDefault: true),
        RegexPattern(id: UUID(), name: String(localized: "Reference Number"), pattern: "(?i)\\b(?:REF|REFERENCE)[-_]?[A-Z0-9]{6,15}\\b", enabled: false, isDefault: true),
        
        // Optional patterns (disabled by default)
        RegexPattern(id: UUID(), name: String(localized: "Generic ID"), pattern: "(?i)\\b([A-Z0-9]{2,8})[-_\\s·・]?([0-9]{2,8})\\b", enabled: false, isDefault: true),
        RegexPattern(id: UUID(), name: String(localized: "Phone"), pattern: "\\b(?:\\+?\\d{1,3}[-\\s]?)?(?:\\d[-\\s]?){7,12}\\d\\b", enabled: false, isDefault: true),
        RegexPattern(id: UUID(), name: String(localized: "Invoice"), pattern: "\\b\\d{2,4}-\\d{3,6}-\\d{2,4}\\b", enabled: false, isDefault: true)
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
