//
//  JSONStore.swift
//  ScreenShotAutoRun
//
//  Created by poppod on 9/8/2568 BE.
//

import Foundation

struct ProcessedAsset: Codable, Identifiable {
    var id: String { localId }
    let localId: String
    let createdAt: Date
    let ocrText: String
    let codes: [AVCodeMatchDTO]
}

struct AVCodeMatchDTO: Codable, Hashable {
    let canonical: String
    let prefix: String
    let digits: String
    let confidence: Int
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

    private func save() {
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
