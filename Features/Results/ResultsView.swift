import SwiftUI
import UIKit

struct ResultsView: View {
    @StateObject var vm = ResultsViewModel()
    @Environment(\.openURL) private var openURL
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var showClearConfirm = false

    var body: some View {
        VStack {
            Picker("Category", selection: $vm.selectedCategory) {
                ForEach(vm.categories, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])
            List {
                ForEach(vm.cards) { r in
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(r.ids, id: \.value) { c in
                            HStack {
                                Text(c.value)
                                    .font(.headline)
                                    .underline(true)
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
                                
                                Button(action: {
                                    if let url = searchURL(for: c.value) { openURL(url) }
                                }) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        HStack {
                            Text(r.assetId).font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text(r.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                        }
                    }
                }
                .onDelete(perform: vm.delete)
            }
        }
        .navigationTitle("Detected IDs")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Clear") { showClearConfirm = true }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Export CSV") {
                    if let url = vm.exportCSV() {
                        shareURL = url
                        showShare = true
                    }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = shareURL {
                ActivityView(activityItems: [url])
            }
        }
        .alert("Remove all results?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) { vm.clearAll() }
        }
        .onAppear { vm.load() }
        .onChange(of: vm.selectedCategory) { _ in vm.applyFilter() }
    }

    private func searchURL(for id: String) -> URL? {
        let q = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
        return URL(string: "https://www.google.com/search?q=\(q)")
    }
}
