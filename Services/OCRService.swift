//
//  OCRService.swift
//  ScreenShotAutoRun
//
//  Created by poppod on 9/8/2568 BE.
//

import Vision
import UIKit

struct OCRLine { let text: String; let box: CGRect }
struct OCRResult { let fullText: String; let lines: [OCRLine] }

protocol OCRService { func recognizeText(cgImage: CGImage) async throws -> OCRResult }

final class OCRServiceImpl: OCRService {
    func recognizeText(cgImage: CGImage) async throws -> OCRResult {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        req.recognitionLanguages = ["en-US","ja-JP"] // เพิ่มได้
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([req])

        let results = req.results ?? []
        var lines:[OCRLine] = []; var all:[String] = []
        for r in results {
            if let best = r.topCandidates(1).first?.string, !best.isEmpty {
                lines.append(.init(text: best, box: r.boundingBox))
                all.append(best)
            }
        }
        return .init(fullText: all.joined(separator: "\n"), lines: lines)
    }
}
