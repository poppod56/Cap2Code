//
//  ResultsView.swift
//  ScreenShotAutoRun
//
//  Created by poppod on 9/8/2568 BE.
//

//
//  ResultsView.swift
//  ScreenShotAutoRun
//
//  Created by poppod on 9/8/2568 BE.
//

import SwiftUI
import UIKit

struct ResultsView: View {
    @StateObject var vm = ResultsViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        List(vm.rows) { r in
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Button(action: {
                        if let url = searchURL(for: r.canonical) { openURL(url) }
                    }) {
                        Text(r.canonical)
                            .font(.headline)
                            .underline(true)
                    }
                    .contextMenu {
                        Button("Copy code") {
                            UIPasteboard.general.string = r.canonical
                        }
                        Button("Copy OCR") {
                            if let ocr = JSONStore.shared.get(r.assetId)?.ocrText {
                                UIPasteboard.general.string = ocr
                            }
                        }
                    }
                    Text(r.assetId).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(r.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                    Text("conf \(r.confidence)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Detected Codes")
        .onAppear { vm.load() }
    }
    
    private func searchURL(for code: String) -> URL? {
        let q = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
        return URL(string: "https://www.google.com/search?q=\(q)")
    }
}

