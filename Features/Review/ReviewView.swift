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
                        if let first = p.ids.first {
                            Text(first.value).font(.headline)
                        } else {
                            Text("No ID found").foregroundStyle(.secondary)
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
                Text("Detected IDs").font(.headline)
                if processed.ids.isEmpty {
                    Text("—").foregroundStyle(.secondary)
                } else {
                    ForEach(processed.ids, id: \.self) { c in
                        Text(c.value).bold()
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
