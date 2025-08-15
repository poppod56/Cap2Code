//
//  ImportViewModel.swift
//  ScreenShotAutoRun
//
//  Created by poppod on 9/8/2568 BE.
//

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

    // MARK: - Processing Controls
    @Published var isPaused: Bool = false
    @Published var isCancelled: Bool = false
    private var processingTask: Task<Void, Never>?

    // Helper for UI
    var pauseButtonTitle: String { isPaused ? String(localized: "Resume") : String(localized: "Pause") }

    let photo: PhotoService = PhotoServiceImpl()
    let ocr: OCRService = OCRServiceImpl()
    let detector: AVCodeDetector = AVCodeDetectorImpl()
    let store = JSONStore.shared
    

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
            // re-run detector on stored OCR text only (no new OCR)
            let codes = detector.findCodes(in: p.ocrText).map {
                AVCodeMatchDTO(
                    canonical: $0.canonical,
                    prefix: $0.prefix,
                    digits: $0.digits,
                    confidence: $0.confidence
                )
            }
            let updated = ProcessedAsset(
                localId: p.localId,
                createdAt: p.createdAt,
                ocrText: p.ocrText,
                codes: codes
            )
            store.upsert(updated)
            done += 1
            await MainActor.run { self.progress = done / total }
        }
        await MainActor.run { self.state = .loaded }
    }

    func redetectOne(localId: String) async {
        guard let p = store.get(localId) else { return }
        let codes = detector.findCodes(in: p.ocrText).map {
            AVCodeMatchDTO(
                canonical: $0.canonical,
                prefix: $0.prefix,
                digits: $0.digits,
                confidence: $0.confidence
            )
        }
        let updated = ProcessedAsset(
            localId: p.localId,
            createdAt: p.createdAt,
            ocrText: p.ocrText,
            codes: codes
        )
        store.upsert(updated)
    }
    func asset(with localId: String) -> PHAsset? {
        assets.first(where: { $0.localIdentifier == localId })
    }

    @MainActor
    func processAll() async {
        // Prevent re-entry if a task is already running
        guard processingTask == nil else { return }

        isPaused = false
        isCancelled = false
        state = .processing
        progress = 0

        // Snapshot list to process to keep iteration stable
        let toProcess = assets
        let total = Double(max(toProcess.count, 1))
        var done = 0.0

        processingTask = Task { [weak self] in
            guard let self = self else { return }
            for a in toProcess {
                // Cancellation guard
                if Task.isCancelled || self.isCancelled { break }

                // Pause loop (cooperative)
                while self.isPaused {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    if Task.isCancelled || self.isCancelled { break }
                }
                if Task.isCancelled || self.isCancelled { break }

                // Skip already processed
                if self.store.get(a.localIdentifier) != nil {
                    done += 1
                    await MainActor.run { self.progress = done / total }
                    continue
                }

                do {
                    let cg = try await self.photo.requestCGImage(for: a)
                    let res = try await self.ocr.recognizeText(cgImage: cg)
                    let codes = self.detector.findCodes(in: res.fullText).map {
                        AVCodeMatchDTO(canonical: $0.canonical, prefix: $0.prefix, digits: $0.digits, confidence: $0.confidence)
                    }
                    let item = ProcessedAsset(localId: a.localIdentifier, createdAt: a.creationDate ?? Date(), ocrText: res.fullText, codes: codes)
                    self.store.upsert(item)
                } catch {
                    // Skip failures silently
                }

                done += 1
                await MainActor.run { self.progress = done / total }
            }

            await MainActor.run {
                self.processingTask = nil
                self.state = .loaded
            }
        }

        // Detach; caller doesn't await the loop
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
