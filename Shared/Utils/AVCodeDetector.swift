//
//  AVCodeDetector.swift
//  ScreenShotAutoRun
//
//  Created by poppod on 9/8/2568 BE.
//

import Foundation

struct AVCodeMatch: Hashable {
    let canonical: String
    let prefix: String
    let digits: String
    let confidence: Int
}

protocol AVCodeDetector { func findCodes(in text: String) -> [AVCodeMatch] }

final class AVCodeDetectorImpl: AVCodeDetector {

    // Expanded allow-list of common prefixes (A–Z 2..6 chars)
    private let allowedPrefixes: Set<String> = [
        // IP/SS series
        "IPX","IPZ","IPTD","IPVR","SSNI","SNIS","SSIS","SSPD",
        // S series
        "STAR","STARS","SIVR","SDDE",
        // Moodyz / Madonna / Prestige / IdeaPocket / S1 / Attackers etc.
        "MIDE","MIDV","MEYD","PPPD","RBD","WANZ","ATID","ADN","PRED",
        // Others frequently seen
        "ABP","ABW","EYAN","JUL","JUFE","NHDTA","XVSR","GVG","EBOD","HMN",
        "KTRA","KIRE","XRW","KAWD","OKSN","NTRD","HUNTA","MKMP","APNS",
        "NACR","NATR","GETS","FSDSS","DASD"
    ]

    // Popular numeric-leading site/series codes
    private let siteSeriesPrefixes: [String] = [
        "300MIUM","300MAAN","300NTK","259LUXU","259MMH","259ANAB",
        "277DCV","200GANA","261ARA","326EKB"
    ]

    // Common separators seen in OCR (hyphen, underscore, space, middle dots)
    private let sep = "[-_\\s·・]"

    // Map Thai numerals → ASCII digits
    private let digitMap: [Character: Character] = [
        "๐":"0","๑":"1","๒":"2","๓":"3","๔":"4",
        "๕":"5","๖":"6","๗":"7","๘":"8","๙":"9"
    ]

    func findCodes(in text: String) -> [AVCodeMatch] {
        // Normalize width (fullwidth → halfwidth) and numerals; keep case (regex is (?i))
        let half = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        let normalized = normalizeNumerals(half)

        var out: [AVCodeMatch] = []

        // 0) Fuzzy fix for common OCR mistakes (token-level)
        let pre = normalized // disable fuzzy token fixes to avoid altering true codes like START-234

        // 1) FC2-PPV
        out += match(pre, pattern: "(?i)\\bFC2\(sep)?PPV\(sep)?(\\d{4,7})\\b") { g in
            .init(canonical: "FC2-PPV-\(g[1])", prefix: "FC2-PPV", digits: g[1], confidence: 3)
        }

        // 2) Caribbeancom style NN-NN
        out += match(pre, pattern: "(?i)\\bCARIB(?:BEANCOM)?\(sep)?(\\d{3,4})[-_](\\d{3,4})\\b") { g in
            .init(canonical: "CARIBBEANCOM-\(g[1])-\(g[2])", prefix: "CARIBBEANCOM", digits: "\(g[1])-\(g[2])", confidence: 2)
        }

        // 3) HEYZO / 1PONDO / 10MUSUME (a.k.a. 10MU)
        out += match(pre, pattern: "(?i)\\bHEYZO\(sep)?(\\d{3,7})\\b") { g in
            .init(canonical: "HEYZO-\(g[1])", prefix: "HEYZO", digits: g[1], confidence: 2)
        }
        out += match(pre, pattern: "(?i)\\b1PONDO\(sep)?(\\d{3,7})\\b") { g in
            .init(canonical: "1PONDO-\(g[1])", prefix: "1PONDO", digits: g[1], confidence: 2)
        }
        out += match(pre, pattern: "(?i)\\b(10MU|10MUSUME)\(sep)?(\\d{3,7})\\b") { g in
            .init(canonical: "10MUSUME-\(g[2])", prefix: "10MUSUME", digits: g[2], confidence: 2)
        }

        // 4) Numeric-leading series (300/259/…)
        let seriesAlt = siteSeriesPrefixes.joined(separator: "|")
        out += match(pre, pattern: "(?i)\\b(\(seriesAlt))\(sep)?(\\d{2,6})\\b") { g in
            .init(canonical: "\(g[1].uppercased())-\(g[2])", prefix: g[1].uppercased(), digits: g[2], confidence: 3)
        }

        // 5) Allowed studio prefixes with separator (e.g., SSNI-123 / STAR 153)
        let allowAlt = allowedPrefixes.sorted { $0.count > $1.count }.joined(separator: "|")
        out += match(pre, pattern: "(?i)\\b(\(allowAlt))\(sep)?(\\d{2,6})\\b") { g in
            let p = g[1].uppercased(), d = g[2]
            guard self.allowedPrefixes.contains(p) else { return nil }
            guard d.count >= 2 else { return nil }
            return .init(canonical: "\(p)-\(d)", prefix: p, digits: d, confidence: 3)
        }

        // 6) No-separator variant (e.g., SSNI123)
        out += match(pre, pattern: "(?i)\\b(\(allowAlt))(\\d{3,6})\\b") { g in
            let p = g[1].uppercased(), d = g[2]
            guard self.allowedPrefixes.contains(p) else { return nil }
            return .init(canonical: "\(p)-\(d)", prefix: p, digits: d, confidence: 2)
        }

        // 7) Generic allow-list-guarded fallback (kept for compatibility)
        out += match(pre, pattern: "(?i)\\b([A-Z]{2,6})\(sep)?(\\d{3,6})\\b") { g in
            let p = g[1].uppercased(), d = g[2]
            guard self.allowedPrefixes.contains(p) else { return nil }
            return .init(canonical: "\(p)-\(d)", prefix: p, digits: d, confidence: 2)
        }

        // 8) Generic fallback without allow-list (low confidence; to catch things like HBOW-2369, SPSC-38)
        out += match(pre, pattern: "(?i)\\b([A-Z]{2,8})\(sep)?(\\d{2,6})\\b") { g in
            let p = g[1].uppercased(), d = g[2]
            // basic guards to reduce false positives
            guard !(p.count <= 2 && d.count <= 2) else { return nil }
            // filter common non-code tokens like counts "K" / "M"
            if d.count <= 2 && (p == "K" || p == "M") { return nil }
            return .init(canonical: "\(p)-\(d)", prefix: p, digits: d, confidence: 1)
        }

        // Dedupe by canonical
        var seen = Set<String>()
        var res: [AVCodeMatch] = []
        for m in out {
            if !seen.contains(m.canonical) {
                seen.insert(m.canonical)
                res.append(m)
            }
        }
        return res
    }

    // MARK: - Helpers

    private func normalizeNumerals(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            if let mapped = digitMap[ch] {
                out.append(mapped)
            } else {
                out.append(ch)
            }
        }
        return out
    }

    private func applyFuzzyTokenFixes(_ s: String) -> String {
        // Disabled by user request: do not alter tokens; return input unchanged
        return s
    }

    private func match(_ s: String, pattern: String, build: ([String]) -> AVCodeMatch?) -> [AVCodeMatch] {
        let re = try! NSRegularExpression(pattern: pattern)
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            var g: [String] = []
            for i in 0..<m.numberOfRanges { g.append(ns.substring(with: m.range(at: i))) }
            return build(g)
        }
    }
}
