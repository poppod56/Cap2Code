//
//  ReviewView.swift
//  ScreenShotAutoRun
//
//  Created by poppod on 9/8/2568 BE.
//

import SwiftUI
import Photos

struct ReviewView: View {
    @StateObject var vm = ReviewViewModel()

    var body: some View {
        List {
            ForEach(vm.items) { p in
                NavigationLink {
                    ReviewDetailView(processed: p)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(p.localId).font(.footnote).foregroundStyle(.secondary)
                        if let first = p.codes.first {
                            Text(first.canonical).font(.headline)
                        } else {
                            Text("No code found").foregroundStyle(.secondary)
                        }
                        Text(p.createdAt.formatted()).font(.caption2)
                    }
                }
            }
        }
        .navigationTitle("Review (Per Image)")
        .onAppear { vm.load() }
    }
}

struct ReviewDetailView: View {
    let processed: ProcessedAsset
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Detected Codes").font(.headline)
                if processed.codes.isEmpty {
                    Text("—").foregroundStyle(.secondary)
                } else {
                    ForEach(processed.codes, id: \.self) { c in
                        HStack {
                            Text(c.canonical).bold()
                            Spacer()
                            Text("conf \(c.confidence)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Divider()
                Text("OCR Text").font(.headline)
                Text(processed.ocrText).font(.callout).textSelection(.enabled)
            }
            .padding()
        }
        .navigationTitle("Image Detail")
    }
}
