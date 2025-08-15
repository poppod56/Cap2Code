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
                ForEach(r.ids, id: \.value) { c in
                    HStack {
                        Button(action: {
                            if let url = searchURL(for: c.value) { openURL(url) }
                        }) {
                            Text(c.value)
                                .font(.headline)
                                .underline(true)
                        }
                        .contextMenu {
                            Button("Copy ID") {
                                UIPasteboard.general.string = c.value
                            }
                            Button("Search on the web") {
                                if let url = searchURL(for: c.value) { openURL(url) }
                            }
                            Button("Copy OCR") {
                                if let ocr = JSONStore.shared.get(r.assetId)?.ocrText {
                                    UIPasteboard.general.string = ocr
                                }
                            }
                        }
                        Spacer()
                    }
                }
                HStack {
                    Text(r.assetId).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(r.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                }
            }
        }
        .navigationTitle("Detected IDs")
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

    private func searchURL(for id: String) -> URL? {
        let q = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
        return URL(string: "https://www.google.com/search?q=\(q)")
    }
}
