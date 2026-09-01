import AppKit
import Combine
import SwiftUI
import UserNotifications

struct MenuContentView: View {
    @ObservedObject var monitor: SwapMonitor
    @ObservedObject private var notifications = NotificationManager.shared

    private let permissionPoll = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            statistics
            Divider()
            controls
            footer
        }
        .padding(16)
        .frame(width: 330)
        .onAppear {
            notifications.refreshAuthorizationStatus()
            monitor.sampleNow()
        }
        .onReceive(permissionPoll) { _ in
            notifications.refreshAuthorizationStatus()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "memorychip")
                .font(.system(size: 25))
                .foregroundStyle(monitor.errorMessage == nil ? Color.accentColor : Color.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("SwapAlert")
                    .font(.headline)
                Label(statusText, systemImage: monitor.isMonitoring ? "circle.fill" : "pause.circle.fill")
                    .font(.caption)
                    .foregroundStyle(monitor.isMonitoring ? .green : .secondary)
            }

            Spacer()
        }
    }

    private var statistics: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("現在のスワップ")
                    .foregroundStyle(.secondary)
                Text(currentSwapText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            GridRow {
                Text("最終検知")
                    .foregroundStyle(.secondary)
                Text(lastSwapText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            GridRow {
                Text("今回の起動中")
                    .foregroundStyle(.secondary)
                Text("\(monitor.detectedEventCount) 回")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            GridRow {
                Text("最終確認")
                    .foregroundStyle(.secondary)
                Text(monitor.lastCheckedAt?.formatted(date: .omitted, time: .standard) ?? "—")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .font(.callout)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("確認間隔", selection: intervalBinding) {
                Text("2秒").tag(2.0)
                Text("5秒").tag(5.0)
                Text("10秒").tag(10.0)
                Text("30秒").tag(30.0)
            }
            .pickerStyle(.segmented)

            HStack {
                Button(monitor.isMonitoring ? "監視を停止" : "監視を開始") {
                    monitor.toggleMonitoring()
                }

                Button("テスト通知") {
                    notifications.sendTestNotification()
                }
            }

            if notifications.requiresSettingsAction {
                Label("通知がオフです", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button("通知設定を開く") {
                    notifications.openSystemSettings()
                }
            }

            if notifications.isUsingFallback {
                Label("macOS内蔵通知を使用中", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if let message = monitor.errorMessage ?? notifications.lastError {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("swapoutカウンタの増加を監視")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("終了") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private var intervalBinding: Binding<Double> {
        Binding(
            get: { monitor.intervalSeconds },
            set: { monitor.setInterval($0) }
        )
    }

    private var statusText: String {
        if monitor.errorMessage != nil { return "読み取りエラー" }
        return monitor.isMonitoring ? "監視中" : "停止中"
    }

    private var currentSwapText: String {
        guard
            let snapshot = monitor.latestSnapshot,
            let used = snapshot.swapUsedBytes,
            let total = snapshot.swapTotalBytes
        else { return "取得できません" }
        return "\(formatBytes(used)) / \(formatBytes(total))"
    }

    private var lastSwapText: String {
        guard let date = monitor.lastSwapAt else { return "まだありません" }
        return "\(date.formatted(date: .omitted, time: .shortened))（\(formatBytes(monitor.lastSwapBytes))）"
    }

    private func formatBytes(_ value: UInt64) -> String {
        let clamped = value > UInt64(Int64.max) ? Int64.max : Int64(value)
        return byteFormatter.string(fromByteCount: clamped)
    }
}
