import Photos
import UIKit

protocol PhotoService {
    func requestAccess() async throws
    func fetchAllScreenshots() async -> [PHAsset]
    func requestThumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage?
    func requestCGImage(for asset: PHAsset) async throws -> CGImage
    func importImages(at urls: [URL]) async throws -> [PHAsset]
    func deleteAssets(_ assets: [PHAsset]) async throws
}

final class PhotoServiceImpl: PhotoService {
    func requestAccess() async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "Photo", code: 1, userInfo: [NSLocalizedDescriptionKey:String(localized: "Photos access not granted")])
        }
    }

    func fetchAllScreenshots() async -> [PHAsset] {
        let col = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil)
        guard let album = col.firstObject else { return [] }
        let opt = PHFetchOptions()
        opt.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        opt.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let res = PHAsset.fetchAssets(in: album, options: opt)
        var arr: [PHAsset] = []
        res.enumerateObjects { a,_,_ in arr.append(a) }
        return arr
    }

    func requestThumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            // Avoid multiple callbacks with degraded images
            opts.deliveryMode = .highQualityFormat
            opts.isSynchronous = false
            opts.isNetworkAccessAllowed = true
            var resumed = false
            PHImageManager.default().requestImage(for: asset,
                                                  targetSize: targetSize,
                                                  contentMode: .aspectFill,
                                                  options: opts) { img, info in
                // If Photos still delivers degraded images, ignore them.
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? NSNumber)?.boolValue ?? false
                guard !isDegraded else { return }
                // Ensure we only resume once
                if !resumed {
                    resumed = true
                    cont.resume(returning: img)
                }
            }
        }
    }

    func requestCGImage(for asset: PHAsset) async throws -> CGImage {
        try await withCheckedThrowingContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.version = .current
            opts.isSynchronous = false
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opts) { data, _, _, _ in
                guard let data, let ui = UIImage(data: data), let cg = ui.cgImage else {
                    cont.resume(throwing: NSError(domain: "Photo", code: 2, userInfo: [NSLocalizedDescriptionKey:String(localized: "Unable to convert to CGImage")]))
                    return
                }
                cont.resume(returning: cg)
            }
        }
    }

    func importImages(at urls: [URL]) async throws -> [PHAsset] {
        try await withCheckedThrowingContinuation { cont in
            var identifiers: [String] = []
            PHPhotoLibrary.shared().performChanges({
                for u in urls {
                    if let req = try? PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: u),
                       let id = req.placeholderForCreatedAsset?.localIdentifier {
                        identifiers.append(id)
                    }
                }
            }) { success, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                if success {
                    let fetch = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
                    var assets: [PHAsset] = []
                    fetch.enumerateObjects { a, _, _ in assets.append(a) }
                    cont.resume(returning: assets)
                } else {
                    cont.resume(returning: [])
                }
            }
        }
    }

    func deleteAssets(_ assets: [PHAsset]) async throws {
        try await withCheckedThrowingContinuation { cont in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }) { _, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }
}
//
//  PhotoService.swift
//  ScreenShotAutoRun
//
//  Created by poppod on 9/8/2568 BE.
//

