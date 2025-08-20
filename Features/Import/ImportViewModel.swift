import Foundation
import Photos
import SwiftUI
import UIKit

final class ImportViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case processing
        case error(String)
    }

    @Published var state: State = .idle
    @Published var assets: [PHAsset] = []
    @Published var progress: Double = 0

    @Published var isPaused: Bool = false
    @Published var isCancelled: Bool = false
    private var processingTask: Task<Void, Never>?

    var pauseButtonTitle: String { isPaused ? String(localized: "Resume") : String(localized: "Pause") }

    let photo: PhotoService = PhotoServiceImpl()
    let ocr: OCRService = OCRServiceImpl()
    let detector: IDDetector = IDDetectorImpl()
    let store = JSONStore.shared
    let patterns = PatternStore.shared
    @Published var currentAlbumTitle: String = String(localized: "Screenshots")

    func fetchAlbums() async -> [PHAssetCollection] {
        await photo.fetchAlbums()
    }

    func loadAssets(from collection: PHAssetCollection) {
        Task {
            do {
                await MainActor.run { self.state = .loading }
                try await photo.requestAccess()
                let list = await photo.fetchAssets(in: collection)
                await MainActor.run {
                    self.assets = list
                    self.state = .loaded
                    self.currentAlbumTitle = collection.localizedTitle ?? String(localized: "Screenshots")
                }
            } catch {
                await MainActor.run { self.state = .error(error.localizedDescription) }
            }
        }
    }

    @MainActor
    func importFromLibrary(identifiers: [String]) {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var list: [PHAsset] = []
        fetch.enumerateObjects { a, _, _ in list.append(a) }
        addAssets(list)
    }

    func importFromFiles(urls: [URL]) {
        Task {
            if let new = try? await photo.importImages(at: urls) {
                await MainActor.run { self.addAssets(new) }
            }
        }
    }

    @MainActor
    private func addAssets(_ new: [PHAsset]) {
        guard !new.isEmpty else { return }
        var existing = Set(assets.map { $0.localIdentifier })
        for a in new {
            if existing.insert(a.localIdentifier).inserted {
                assets.append(a)
            }
        }
        if state == .idle { state = .loaded }
    }

    @MainActor
    func deleteAssets(ids: Set<String>) async {
        let toDelete = assets.filter { ids.contains($0.localIdentifier) }
        do {
            try await photo.deleteAssets(toDelete)
            assets.removeAll { ids.contains($0.localIdentifier) }
            store.delete(Array(ids))
        } catch {
        }
    }

    func processedItem(for asset: PHAsset) -> ProcessedAsset? {
        store.get(asset.localIdentifier)
    }

    func redetectAll() async {
        let items = store.all()
        guard !items.isEmpty else { return }
        await MainActor.run {
            self.state = .processing
            self.progress = 0
        }
        let total = Double(items.count)
        var done = 0.0

        for p in items {
            let ids = detector.find(in: p.ocrText, patterns: patterns.enabledPatterns)
                .map { DetectedIDDTO(value: $0.value) }
            let updated = ProcessedAsset(
                localId: p.localId,
                createdAt: p.createdAt,
                ocrText: p.ocrText,
                ids: ids,
                category: p.category
            )
            store.upsert(updated)
            done += 1
            await MainActor.run { self.progress = done / total }
        }
        await MainActor.run { self.state = .loaded }
    }

    func redetectOne(localId: String) async {
        guard let p = store.get(localId) else { return }
        let ids = detector.find(in: p.ocrText, patterns: patterns.enabledPatterns)
            .map { DetectedIDDTO(value: $0.value) }
        let updated = ProcessedAsset(
            localId: p.localId,
            createdAt: p.createdAt,
            ocrText: p.ocrText,
            ids: ids,
            category: p.category
        )
        store.upsert(updated)
    }
    func asset(with localId: String) -> PHAsset? {
        assets.first(where: { $0.localIdentifier == localId })
    }

    func processCamera(image: UIImage) async -> ProcessedAsset? {
        guard let cg = image.cgImage else { return nil }
        do {
            let res = try await ocr.recognizeText(cgImage: cg)
            let ids = detector.find(in: res.fullText, patterns: patterns.enabledPatterns)
                .map { DetectedIDDTO(value: $0.value) }
            let localId = UUID().uuidString
            let item = ProcessedAsset(localId: localId, createdAt: Date(), ocrText: res.fullText, ids: ids, category: "Camera")
            store.upsert(item)
            return item
        } catch {
            return nil
        }
    }

    @MainActor
    func processAll() async {
        guard processingTask == nil else { return }

        isPaused = false
        isCancelled = false
        state = .processing
        progress = 0

        let toProcess = assets
        let total = Double(max(toProcess.count, 1))

        processingTask = Task { [weak self, toProcess, total] in
            guard let self = self else { return }
            var done = 0.0
            for a in toProcess {
                if Task.isCancelled || self.isCancelled { break }

                while self.isPaused {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if Task.isCancelled || self.isCancelled { break }
                }
                if Task.isCancelled || self.isCancelled { break }

                if self.store.get(a.localIdentifier) != nil {
                    done += 1
                    await MainActor.run { self.progress = done / total }
                    continue
                }

                do {
                    let cg = try await self.photo.requestCGImage(for: a)
                    let res = try await self.ocr.recognizeText(cgImage: cg)
                    let ids = self.detector.find(in: res.fullText, patterns: self.patterns.enabledPatterns)
                        .map { DetectedIDDTO(value: $0.value) }
                    let item = ProcessedAsset(localId: a.localIdentifier, createdAt: a.creationDate ?? Date(), ocrText: res.fullText, ids: ids, category: self.currentAlbumTitle)
                    self.store.upsert(item)
                } catch {
                }

                done += 1
                await MainActor.run { self.progress = done / total }
            }

            await MainActor.run {
                self.processingTask = nil
                self.state = .loaded
            }
        }

        _ = processingTask
    }

    @MainActor
    func pauseProcessing() {
        guard processingTask != nil else { return }
        isPaused = true
    }

    @MainActor
    func resumeProcessing() {
        guard processingTask != nil else { return }
        isPaused = false
    }

    @MainActor
    func onPauseResumeTapped() {
        if isPaused { resumeProcessing() } else { pauseProcessing() }
    }

    @MainActor
    func stopProcessing() {
        guard let task = processingTask else { return }
        isCancelled = true
        isPaused = false
        task.cancel()
    }
}
