//
//  AssetThumbnailView.swift
//  ScreenShotAutoRun
//

import SwiftUI
import Photos
import UIKit

@MainActor
struct AssetThumbnailView: View {
    let asset: PHAsset
    let photo: PhotoService
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Rectangle().fill(.gray.opacity(0.15))
                ProgressView()
            }
        }
        .frame(height: 110)
        .clipped()
        .task {
            // อัปเดตบนเมนเธรดด้วย @MainActor อยู่แล้ว
            let img = await photo.requestThumbnail(for: asset, targetSize: .init(width: 300, height: 300))
            image = img
        }
    }
}
