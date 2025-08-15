import Foundation

struct DetectedID: Hashable {
    let value: String
}

protocol IDDetector {
    func find(in text: String, patterns: [RegexPattern]) -> [DetectedID]
}

final class IDDetectorImpl: IDDetector {
    func find(in text: String, patterns: [RegexPattern]) -> [DetectedID] {
        var results: [DetectedID] = []
        for p in patterns where p.enabled {
            guard let re = try? NSRegularExpression(pattern: p.pattern, options: [.caseInsensitive]) else { continue }
            let ns = text as NSString
            let matches = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
            for m in matches {
                results.append(DetectedID(value: ns.substring(with: m.range)))
            }
        }
        var seen = Set<String>()
        var unique: [DetectedID] = []
        for r in results {
            if seen.insert(r.value).inserted {
                unique.append(r)
            }
        }
        return unique
    }
}
