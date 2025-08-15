import SwiftUI
import Photos
import UIKit

struct ImportView: View {
    @ObservedObject var vm: ImportViewModel
    @State private var selectedLocalId: String?
    @State private var showPreviewFull: Bool = false

    var body: some View {
        VStack {
            switch vm.state {
            case .idle:
                Button("Scan") { vm.loadScreenshots() }
                    .buttonStyle(.borderedProminent)

            case .loading:
                ProgressView("Loading Screenshots...")

            case .loaded, .processing, .error(_):
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(vm.assets, id: \.localIdentifier) { asset in
                            Button {
                                selectedLocalId = asset.localIdentifier
                                showPreviewFull = true
                            } label: {
                                AssetThumbnailView(asset: asset, photo: vm.photo)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .allowsHitTesting(!showPreviewFull)
                        }
                    }
                    .padding()
                }
                .safeAreaInset(edge: .bottom) {
                    if !showPreviewFull {
                        VStack(spacing: 8) {
                            if vm.state == .processing {
                                ProgressView(value: vm.progress).padding(.horizontal)
                                HStack {
                                    Button(action: { vm.onPauseResumeTapped() }) {
                                        Text(vm.pauseButtonTitle)
                                    }
                                    .buttonStyle(.bordered)
                                    Button(action: { vm.stopProcessing() }) {
                                        Text("Stop")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            Button(vm.state == .processing ? "Scanning..." : "Scan") {
                                Task { await vm.processAll() }
                            }
                            .disabled(vm.state == .processing)
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Screenshots")
        .sheet(isPresented: $showPreviewFull) {
            if let id = selectedLocalId, let asset = vm.asset(with: id) {
                NavigationStack {
                    PreviewDetailView(vm: vm, localId: id, asset: asset, photo: vm.photo)
                }
                .interactiveDismissDisabled(false)
            } else {
                NavigationStack {
                    VStack(spacing: 16) {
                        Text("Image not available")
                    }
                    .padding()
                }
                .interactiveDismissDisabled(false)
            }
        }
    }
}

struct PreviewDetailView: View {
    @ObservedObject var vm: ImportViewModel
        let localId: String
        let asset: PHAsset
        let photo: PhotoService

    @State private var fullImage: UIImage?
    @State private var isRedetecting = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Group {
                    if let img = fullImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .contentShape(Rectangle())
                            .zIndex(0)
                    } else {
                        Rectangle().fill(.gray.opacity(0.15)).overlay { ProgressView() }
                            .frame(height: 220)
                            .zIndex(0)
                    }
                }
                .zIndex(1)

                if let p = vm.processedItem(for: asset) {
                    Divider()
                    HStack {
                        Text("Detected IDs").font(.headline)
                        Spacer()
                        Button(action: {
                            isRedetecting = true
                            Task {
                                await vm.redetectOne(localId: asset.localIdentifier)
                                await MainActor.run { isRedetecting = false }
                            }
                        }) {
                            Group {
                                if isRedetecting {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("Re-scan this image")
                                }
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.bordered)
                    }
                    if p.ids.isEmpty {
                        Text("—").foregroundStyle(.secondary)
                    } else {
                        ForEach(p.ids, id: \.value) { c in
                            HStack {
                                Text(c.value)
                                    .bold()
                                    .underline()
                                    .textSelection(.enabled)
                                    .onTapGesture {
                                        if let url = searchURL(for: c.value) { openURL(url) }
                                    }
                                    .contextMenu {
                                        Button("Copy ID") {
                                            UIPasteboard.general.string = c.value
                                        }
                                        Button("Search on the web") {
                                            if let url = searchURL(for: c.value) { openURL(url) }
                                        }
                                    }
                                Spacer()
                            }
                        }
                    }
                    Divider()
                    HStack {
                        Text("OCR Text").font(.headline)
                        Spacer()
                        Button(action: { UIPasteboard.general.string = p.ocrText }) {
                            Text("Copy OCR")
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.bordered)
                    }
                    SelectableTextView(text: p.ocrText)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle("Preview")
        .task(id: localId) {
            if let cg = try? await photo.requestCGImage(for: asset) {
                if asset.localIdentifier == localId {
                    fullImage = UIImage(cgImage: cg)
                }
            }
        }
    }

    private func searchURL(for id: String) -> URL? {
        let q = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
        return URL(string: "https://www.google.com/search?q=\(q)")
    }
}
