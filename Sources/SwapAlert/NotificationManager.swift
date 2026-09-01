import AppKit
import Foundation
import UserNotifications

enum NotificationDeliveryMode: Equatable {
    case checking
    case native
    case appleScriptFallback
    case userDenied
}

final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var deliveryMode: NotificationDeliveryMode = .checking
    @Published private(set) var lastError: String?

    var requiresSettingsAction: Bool {
        deliveryMode == .userDenied
    }

    var isUsingFallback: Bool {
        deliveryMode == .appleScriptFallback
    }

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        refreshAuthorizationStatus()
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if error != nil {
                    // macOS rejects UserNotifications for ad-hoc signed apps because
                    // they have no Apple-issued Team Identifier. Use the signed
                    // system osascript process as the local notification provider.
                    self?.deliveryMode = .appleScriptFallback
                    self?.lastError = nil
                } else if !granted {
                    self?.deliveryMode = .userDenied
                    self?.lastError = "通知が許可されていません"
                } else {
                    self?.deliveryMode = .native
                    self?.lastError = nil
                }
                self?.refreshAuthorizationStatus()
            }
        }
    }

    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
                guard self?.deliveryMode != .appleScriptFallback else { return }

                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self?.deliveryMode = .native
                    self?.lastError = nil
                case .denied:
                    self?.deliveryMode = .userDenied
                case .notDetermined:
                    self?.deliveryMode = .checking
                @unknown default:
                    self?.deliveryMode = .checking
                }
            }
        }
    }

    func sendSwapNotification(pages: UInt64, bytes: UInt64) {
        let body = "\(ByteCountFormatter.string(fromByteCount: clampedInt64(bytes), countStyle: .memory))（\(pages.formatted())ページ）がディスクへ退避されました。"
        deliver(title: "メモリのスワップを検知", body: body, identifierPrefix: "swap")
    }

    func sendTestNotification() {
        deliver(title: "SwapAlert テスト", body: "通知は正常に動作しています。", identifierPrefix: "test")
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func deliver(title: String, body: String, identifierPrefix: String) {
        if deliveryMode == .appleScriptFallback {
            deliverUsingAppleScript(title: title, body: body)
            return
        }

        guard deliveryMode == .native else {
            requestAuthorization()
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "swap-events"

        let identifier = "\(identifierPrefix)-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            guard let error else { return }
            DispatchQueue.main.async {
                self?.lastError = error.localizedDescription
            }
        }
    }

    private func deliverUsingAppleScript(title: String, body: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-l",
            "JavaScript",
            "-e",
            "function run(argv) { const app = Application.currentApplication(); app.includeStandardAdditions = true; app.displayNotification(argv[1], { withTitle: argv[0], soundName: \"Glass\" }); }",
            "--",
            title,
            body
        ]
        process.terminationHandler = { [weak self] process in
            guard process.terminationStatus != 0 else { return }
            DispatchQueue.main.async {
                self?.lastError = "macOS内蔵通知を送信できませんでした"
            }
        }

        do {
            try process.run()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func clampedInt64(_ value: UInt64) -> Int64 {
        value > UInt64(Int64.max) ? Int64.max : Int64(value)
    }
}
