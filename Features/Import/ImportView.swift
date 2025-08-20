import SwiftUI
import Photos
import UIKit
import AVFoundation

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
    @State private var showCameraPreview = false
    @State private var isCameraProcessing = false
    @State private var cameraPermissionStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var showPermissionAlert = false

    var body: some View {
        VStack {
            switch vm.state {
            case .idle:
                VStack(spacing: 12) {
                    Button(String(localized: "Select Album")) { showAlbumPicker = true }
                        .buttonStyle(.borderedProminent)
                    
                    Button {
                        checkCameraPermissionAndOpenCamera()
                    } label: {
                        Image(systemName: "camera")
                            .font(.title2)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(String(localized: "Camera"))
                }

            case .loading:
                ProgressView(String(localized: "Loading Photos..."))

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
                                HStack(spacing: 12) {
                                    Button(String(localized: "Scan Selected")) {
                                        let selectedIds = Array(selection)
                                        Task {
                                            await vm.processSelected(localIds: selectedIds)
                                        }
                                        selection.removeAll()
                                        isSelecting = false
                                    }
                                    .disabled(selection.isEmpty)
                                    .buttonStyle(.borderedProminent)
                                    
                                    Button(String(localized: "Delete")) {
                                        let ids = selection
                                        Task {
                                            await vm.deleteAssets(ids: ids)
                                        }
                                        selection.removeAll()
                                        isSelecting = false
                                    }
                                    .disabled(selection.isEmpty)
                                    .buttonStyle(.bordered)
                                }
                            } else {
                                if vm.state == .processing {
                                    ProgressView(value: vm.progress).padding(.horizontal)
                                    HStack {
                                        Button(action: { vm.onPauseResumeTapped() }) {
                                            Text(vm.pauseButtonTitle)
                                        }
                                        .buttonStyle(.bordered)
                                        Button(action: { vm.stopProcessing() }) {
                                            Text(String(localized: "Stop"))
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                                HStack {
                                    Button(vm.state == .processing ? String(localized: "Scanning...") : String(localized: "Scan")) {
                                        Task { await vm.processAll() }
                                    }
                                    .disabled(vm.state == .processing)
                                    .buttonStyle(.borderedProminent)
                                    
                                    Button {
                                        checkCameraPermissionAndOpenCamera()
                                    } label: {
                                        Image(systemName: "camera")
                                            .font(.title3)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isCameraProcessing)
                                    .accessibilityLabel(String(localized: "Camera"))
                                }
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
                Button(isSelecting ? String(localized: "Done") : String(localized: "Select")) {
                    if isSelecting { selection.removeAll() }
                    isSelecting.toggle()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "Select Album")) { showAlbumPicker = true }
            }
        }
        .onAppear {
            // Check camera permission status on view appear
            cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
        .alert(String(localized: "Camera Permission Required"), isPresented: $showPermissionAlert) {
            Button(String(localized: "Settings")) {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) { }
        } message: {
            Text(String(localized: "Please enable camera access in Settings to take photos for text recognition."))
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
                        Text(String(localized: "Image not available"))
                    }
                    .padding()
                }
                .interactiveDismissDisabled(false)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                // Store in ViewModel
                vm.cameraImage = image
                showCamera = false
                isCameraProcessing = true
                
                Task {
                    let result = await vm.processCamera(image: image)
                    await MainActor.run {
                        isCameraProcessing = false
                        vm.cameraResult = result
                        showCameraPreview = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isCameraProcessing) {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                Text(String(localized: "Processing image..."))
                    .font(.headline)
                Text(String(localized: "Analyzing text and patterns..."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.8))
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showCameraPreview) {
            NavigationStack {
                // Directly use ViewModel storage
                let displayImage = vm.cameraImage
                let displayResult = vm.cameraResult
                
                if let img = displayImage, let result = displayResult {
                    // Processing was successful, show results
                    CameraPreviewDetailView(image: img, result: result)
                } else if let img = displayImage {
                    // Processing failed, show error with the captured image
                    VStack(spacing: 16) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                        
                        Text(String(localized: "Processing Failed"))
                            .font(.headline)
                        Text(String(localized: "Unable to process the captured image"))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(String(localized: "Try Again")) {
                            showCameraPreview = false
                            vm.cameraImage = nil
                            vm.cameraResult = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                checkCameraPermissionAndOpenCamera()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(String(localized: "Close")) {
                            showCameraPreview = false
                            vm.cameraImage = nil
                            vm.cameraResult = nil
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .navigationTitle(String(localized: "Camera"))
                    .navigationBarTitleDisplayMode(.inline)
                } else if let result = displayResult {
                    // Edge case: We have result but no image - show text only
                    VStack(spacing: 16) {
                        Text(String(localized: "Image Lost"))
                            .font(.headline)
                        Text(String(localized: "The camera image was lost, but we have the processing results"))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            if !result.ids.isEmpty {
                                Text(String(localized: "Detected IDs:")).font(.headline)
                                ForEach(result.ids, id: \.value) { id in
                                    Text("• \(id.value)")
                                        .textSelection(.enabled)
                                }
                            }
                            
                            if !result.ocrText.isEmpty {
                                Text(String(localized: "OCR Text:")).font(.headline)
                                SelectableTextView(text: result.ocrText)
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        
                        Button(String(localized: "Close")) {
                            showCameraPreview = false
                            vm.cameraImage = nil
                            vm.cameraResult = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .navigationTitle(String(localized: "Camera Result"))
                    .navigationBarTitleDisplayMode(.inline)
                } else {
                    // Last resort - should not happen in normal use
                    VStack(spacing: 16) {
                        Text(String(localized: "Camera Error"))
                            .font(.headline)
                        Text(String(localized: "Something went wrong with camera processing"))
                            .foregroundStyle(.secondary)
                        
                        Button(String(localized: "Try Camera Again")) {
                            showCameraPreview = false
                            vm.cameraImage = nil
                            vm.cameraResult = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                checkCameraPermissionAndOpenCamera()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(String(localized: "Close")) {
                            showCameraPreview = false
                            vm.cameraImage = nil
                            vm.cameraResult = nil
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .navigationTitle(String(localized: "Camera"))
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }
    
    private func checkCameraPermissionAndOpenCamera() {
        // Always refresh the permission status before checking
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraPermissionStatus {
        case .authorized:
            // Camera access is already granted, open the camera
            showCamera = true
        case .notDetermined:
            // Camera access has not been requested yet, request access
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    // Update the permission status after the request
                    self.cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
                    
                    if granted {
                        // Access granted, open the camera
                        self.showCamera = true
                    } else {
                        // Access denied, show alert
                        self.showPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            // Camera access is denied or restricted, show alert
            showPermissionAlert = true
        @unknown default:
            // Handle any future cases
            showPermissionAlert = true
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
                        Text(String(localized: "Detected IDs")).font(.headline)
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
                                    Text(String(localized: "Re-scan this image"))
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
                                        Button(String(localized: "Copy ID")) {
                                            UIPasteboard.general.string = c.value
                                        }
                                        Button(String(localized: "Search on the web")) {
                                            if let url = searchURL(for: c.value) { openURL(url) }
                                        }
                                    }
                                Spacer()
                            }
                        }
                    }
                    Divider()
                    HStack {
                        Text(String(localized: "OCR Text")).font(.headline)
                        Spacer()
                        Button(action: { UIPasteboard.general.string = p.ocrText }) {
                            Text(String(localized: "Copy OCR"))
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
        .navigationTitle(String(localized: "Preview"))
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Always show the captured image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipped()
                    .background(Color.gray.opacity(0.1))
                
                // Show processing results
                VStack(alignment: .leading, spacing: 16) {
                    // Detected IDs Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "Detected IDs")).font(.headline)
                        if !result.ids.isEmpty {
                            ForEach(result.ids, id: \.value) { id in
                                HStack {
                                    Text(id.value)
                                        .bold()
                                        .underline()
                                        .textSelection(.enabled)
                                        .onTapGesture {
                                            if let url = searchURL(for: id.value) { openURL(url) }
                                        }
                                        .contextMenu {
                                            Button(String(localized: "Copy ID")) {
                                                UIPasteboard.general.string = id.value
                                            }
                                            Button(String(localized: "Search on the web")) {
                                                if let url = searchURL(for: id.value) { openURL(url) }
                                            }
                                        }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                        } else {
                            Text(String(localized: "No IDs detected"))
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                    }
                    
                    Divider()
                    
                    // OCR Text Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(String(localized: "OCR Text")).font(.headline)
                            Spacer()
                            if !result.ocrText.isEmpty {
                                Button(String(localized: "Copy OCR")) {
                                    UIPasteboard.general.string = result.ocrText
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        if !result.ocrText.isEmpty {
                            SelectableTextView(text: result.ocrText)
                                .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        } else {
                            Text(String(localized: "No text detected"))
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(String(localized: "Camera Result"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(String(localized: "Done")) { dismiss() }
            }
        }
    }
    
    private func searchURL(for id: String) -> URL? {
        let q = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
        return URL(string: "https://www.google.com/search?q=\(q)")
    }
}

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
