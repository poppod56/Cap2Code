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
    @State private var shareURL: URL?
    @State private var showShare = false

    var body: some View {
        List(vm.cards) { r in
            VStack(alignment: .leading, spacing: 6) {
                ForEach(r.codes, id: \.canonical) { c in
                    HStack {
                        Button(action: {
                            if let url = searchURL(for: c.canonical) { openURL(url) }
                        }) {
                            Text(c.canonical)
                                .font(.headline)
                                .underline(true)
                        }
                        .contextMenu {
                            Button("Copy code") {
                                UIPasteboard.general.string = c.canonical
                            }
                            Button("Copy OCR") {
                                if let ocr = JSONStore.shared.get(r.assetId)?.ocrText {
                                    UIPasteboard.general.string = ocr
                                }
                            }
                        }
                        Spacer()
                        Text("conf \(c.confidence)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text(r.assetId).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(r.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                }
            }
        }
        .navigationTitle("Detected Codes")
        .toolbar {
            Button("Export CSV") {
                if let url = vm.exportCSV() {
                    shareURL = url
                    showShare = true
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = shareURL {
                ActivityView(activityItems: [url])
            }
        }
        .onAppear { vm.load() }
    }

    private func searchURL(for code: String) -> URL? {
        let q = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
        return URL(string: "https://www.google.com/search?q=\(q)")
    }
}

