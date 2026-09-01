import Darwin
import Foundation

struct MemorySnapshot {
    let swapouts: UInt64
    let swapUsedBytes: UInt64?
    let swapTotalBytes: UInt64?
    let pageSize: UInt64
}

enum MemoryReaderError: LocalizedError {
    case hostStatistics(kern_return_t)
    case pageSize(kern_return_t)

    var errorDescription: String? {
        switch self {
        case .hostStatistics(let result):
            return "仮想メモリ統計を取得できませんでした (\(result))"
        case .pageSize(let result):
            return "メモリページサイズを取得できませんでした (\(result))"
        }
    }
}

enum MemoryReader {
    static func snapshot() throws -> MemorySnapshot {
        var statistics = vm_statistics64()
        var statisticsCount = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let statisticsResult = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(statisticsCount)) { rebound in
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    rebound,
                    &statisticsCount
                )
            }
        }

        guard statisticsResult == KERN_SUCCESS else {
            throw MemoryReaderError.hostStatistics(statisticsResult)
        }

        var pageSize: vm_size_t = 0
        let pageSizeResult = host_page_size(mach_host_self(), &pageSize)
        guard pageSizeResult == KERN_SUCCESS else {
            throw MemoryReaderError.pageSize(pageSizeResult)
        }

        var swapUsage = xsw_usage()
        var swapUsageSize = MemoryLayout<xsw_usage>.size
        let swapUsageResult = sysctlbyname("vm.swapusage", &swapUsage, &swapUsageSize, nil, 0)

        return MemorySnapshot(
            swapouts: statistics.swapouts,
            swapUsedBytes: swapUsageResult == 0 ? swapUsage.xsu_used : nil,
            swapTotalBytes: swapUsageResult == 0 ? swapUsage.xsu_total : nil,
            pageSize: UInt64(pageSize)
        )
    }
}
