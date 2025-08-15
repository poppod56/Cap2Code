import Foundation
import Photos
import SwiftUI

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

    func loadScreenshots() {
        Task {
            do {
                await MainActor.run { self.state = .loading }
                try await photo.requestAccess()
                let list = await photo.fetchAllScreenshots()
                await MainActor.run {
                    self.assets = list
                    self.state = .loaded
                }
            } catch {
                await MainActor.run { self.state = .error(error.localizedDescription) }
            }
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
                ids: ids
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
            ids: ids
        )
        store.upsert(updated)
    }
    func asset(with localId: String) -> PHAsset? {
        assets.first(where: { $0.localIdentifier == localId })
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
        var done = 0.0

        processingTask = Task { [weak self] in
            guard let self = self else { return }
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
                    let item = ProcessedAsset(localId: a.localIdentifier, createdAt: a.creationDate ?? Date(), ocrText: res.fullText, ids: ids)
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
