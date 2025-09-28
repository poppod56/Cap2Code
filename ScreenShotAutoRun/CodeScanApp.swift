import SwiftUI
import FBSDKCoreKit

@main
struct CodeScanApp: App {
    init() {
        ApplicationDelegate.shared.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    ApplicationDelegate.shared.application(
                        UIApplication.shared,
                        open: url,
                        sourceApplication: nil,
                        annotation: [UIApplication.OpenURLOptionsKey.annotation]
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    AppEvents.shared.activateApp()
                }
        }
    }
}
