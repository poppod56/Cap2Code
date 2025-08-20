import SwiftUI
import Photos
import UIKit

struct ImportView: View {
    @ObservedObject var vm: ImportViewModel
    @State private var selectedLocalId: String?
    @State private var showPreviewFull: Bool = false
    @State private var isSelecting: Bool = false
    @State private var selection: Set<String> = []
    @State private var showAlbumPicker = false
    @State private var albums: [PHAssetCollection] = []
    @State private var albumTitle: String = String(localized: "Screenshots")
    @State private var showCamera = false
    @State private var isCameraProcessing = false
    @State private var cameraImage: UIImage?
    @State private var cameraResult: ProcessedAsset?
    @State private var showCameraPreview = false

    var body: some View {
        VStack {
            switch vm.state {
            case .idle:
                VStack(spacing: 16) {
                    Button("Select Album") { showAlbumPicker = true }
                        .buttonStyle(.borderedProminent)
                    Button("Camera") { showCamera = true }
                        .buttonStyle(.bordered)
                }

            case .loading:
                ProgressView("Loading Photos...")

            case .loaded, .processing, .error(_):
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(vm.assets, id: \.localIdentifier) { asset in
                            Button {
                                if isSelecting {
                                    if selection.contains(asset.localIdentifier) {
                                        selection.remove(asset.localIdentifier)
                                    } else {
                                        selection.insert(asset.localIdentifier)
                                    }
                                } else {
                                    selectedLocalId = asset.localIdentifier
                                    showPreviewFull = true
                                }
                            } label: {
                                AssetThumbnailView(asset: asset, photo: vm.photo)
                                    .overlay(alignment: .topTrailing) {
                                        if isSelecting {
                                            Image(systemName: selection.contains(asset.localIdentifier) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(.blue)
                                                .padding(4)
                                        }
                                    }
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
                            if isSelecting {
                                Button("Delete") {
                                    let ids = selection
                                    Task {
                                        await vm.deleteAssets(ids: ids)
                                    }
                                    selection.removeAll()
                                    isSelecting = false
                                }
                                .disabled(selection.isEmpty)
                                .buttonStyle(.borderedProminent)
                            } else {
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
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle(albumTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSelecting ? "Done" : "Select") {
                    if isSelecting { selection.removeAll() }
                    isSelecting.toggle()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Select Album") { showAlbumPicker = true }
            }
        }
        .sheet(isPresented: $showAlbumPicker) {
            NavigationStack {
                List(albums, id: \.localIdentifier) { album in
                    Button(album.localizedTitle ?? "") {
                        albumTitle = album.localizedTitle ?? String(localized: "Screenshots")
                        showAlbumPicker = false
                        vm.loadAssets(from: album)
                    }
                }
                .navigationTitle(String(localized: "Select Album"))
                .onAppear {
                    Task { albums = await vm.fetchAlbums() }
                }
            }
        }
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
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                cameraImage = image
                isCameraProcessing = true
                Task {
                    let result = await vm.processCamera(image: image)
                    await MainActor.run {
                        cameraResult = result
                        isCameraProcessing = false
                        showCameraPreview = result != nil
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isCameraProcessing) {
            VStack { ProgressView("Processing...") }
        }
        .sheet(isPresented: $showCameraPreview) {
            if let img = cameraImage, let result = cameraResult {
                NavigationStack { CameraPreviewDetailView(image: img, result: result) }
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

struct CameraPreviewDetailView: View {
    let image: UIImage
    let result: ProcessedAsset
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()

                Divider()
                HStack {
                    Text("Detected IDs").font(.headline)
                    Spacer()
                }
                if result.ids.isEmpty {
                    Text("—").foregroundStyle(.secondary)
                } else {
                    ForEach(result.ids, id: \.value) { c in
                        HStack {
                            Text(c.value)
                                .bold()
                                .underline()
                                .textSelection(.enabled)
                                .onTapGesture {
                                    if let url = searchURL(for: c.value) { openURL(url) }
                                }
                                .contextMenu {
                                    Button("Copy ID") { UIPasteboard.general.string = c.value }
                                    Button("Search on the web") { if let url = searchURL(for: c.value) { openURL(url) } }
                                }
                            Spacer()
                        }
                    }
                }
                Divider()
                HStack {
                    Text("OCR Text").font(.headline)
                    Spacer()
                    Button(action: { UIPasteboard.general.string = result.ocrText }) {
                        Text("Copy OCR")
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                }
                SelectableTextView(text: result.ocrText)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle("Preview")
    }

    private func searchURL(for id: String) -> URL? {
        let q = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
        return URL(string: "https://www.google.com/search?q=\(q)")
    }
}

struct CameraView: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(parent: CameraView) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.onImage(img)
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
