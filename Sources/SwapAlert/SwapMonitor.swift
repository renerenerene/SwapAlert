import Foundation

final class SwapMonitor: ObservableObject {
    static let shared = SwapMonitor()

    @Published private(set) var isMonitoring = false
    @Published private(set) var latestSnapshot: MemorySnapshot?
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var lastSwapAt: Date?
    @Published private(set) var lastSwapBytes: UInt64 = 0
    @Published private(set) var detectedEventCount = 0
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasRecentSwap = false
    @Published private(set) var intervalSeconds: Double

    private var previousSwapouts: UInt64?
    private var timer: Timer?
    private var recentSwapResetWorkItem: DispatchWorkItem?

    private init() {
        let savedInterval = UserDefaults.standard.double(forKey: "monitorIntervalSeconds")
        intervalSeconds = [2.0, 5.0, 10.0, 30.0].contains(savedInterval) ? savedInterval : 5.0
    }

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        sample()
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    func toggleMonitoring() {
        isMonitoring ? stop() : start()
    }

    func setInterval(_ seconds: Double) {
        guard [2.0, 5.0, 10.0, 30.0].contains(seconds) else { return }
        intervalSeconds = seconds
        UserDefaults.standard.set(seconds, forKey: "monitorIntervalSeconds")
        if isMonitoring {
            scheduleTimer()
        }
    }

    func sampleNow() {
        guard isMonitoring else { return }
        sample()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            self?.sample()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func sample() {
        do {
            let snapshot = try MemoryReader.snapshot()
            defer {
                previousSwapouts = snapshot.swapouts
                latestSnapshot = snapshot
                lastCheckedAt = Date()
                errorMessage = nil
            }

            guard let previousSwapouts else { return }
            guard snapshot.swapouts > previousSwapouts else { return }

            let pages = snapshot.swapouts - previousSwapouts
            let (bytes, overflow) = pages.multipliedReportingOverflow(by: snapshot.pageSize)
            let safeBytes = overflow ? UInt64.max : bytes

            lastSwapAt = Date()
            lastSwapBytes = safeBytes
            detectedEventCount += 1
            markRecentSwap()
            NotificationManager.shared.sendSwapNotification(pages: pages, bytes: safeBytes)
        } catch {
            lastCheckedAt = Date()
            errorMessage = error.localizedDescription
        }
    }

    private func markRecentSwap() {
        recentSwapResetWorkItem?.cancel()
        hasRecentSwap = true

        let workItem = DispatchWorkItem { [weak self] in
            self?.hasRecentSwap = false
        }
        recentSwapResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: workItem)
    }
}
