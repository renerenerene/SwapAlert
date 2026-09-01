import AppKit
import SwiftUI
import UserNotifications

@main
struct SwapAlertApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(monitor: .shared)
        } label: {
            Image(systemName: SwapMonitor.shared.hasRecentSwap ? "memorychip.fill" : "memorychip")
                .accessibilityLabel("SwapAlert")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationManager.shared.configure()
        NotificationManager.shared.requestAuthorization()
        SwapMonitor.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        SwapMonitor.shared.stop()
    }
}
