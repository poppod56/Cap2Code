import SwiftUI
import UIKit

/// A simple wrapper around ``UIActivityViewController`` that can be used from
/// SwiftUI.  It presents the standard iOS share sheet with the provided items.
public struct ActivityView: UIViewControllerRepresentable {
    /// Items to share.
    public let activityItems: [Any]

    /// Creates a new activity view with the given items.
    /// - Parameter activityItems: Objects to pass to ``UIActivityViewController``.
    public init(activityItems: [Any]) {
        self.activityItems = activityItems
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
