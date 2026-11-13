import Darwin
import Foundation

/// 이 프로세스가 지금까지 쓴 CPU 시간과 디스크에서 읽은 양 — 지연 로그용.
/// 스왑으로 나간 모델 메모리를 다시 읽으면 그 양이 `diskBytesRead`에 잡힌다.
public struct ProcessUsage: Sendable, Equatable {
    public let cpuSeconds: Double
    public let diskBytesRead: UInt64

    public struct Delta: Sendable, Equatable {
        public let cpuSeconds: Double
        public let diskMegabytesRead: Double
    }

    public init(cpuSeconds: Double, diskBytesRead: UInt64) {
        self.cpuSeconds = cpuSeconds
        self.diskBytesRead = diskBytesRead
    }

    public static func current() -> ProcessUsage? {
        var info = rusage_info_v4()
        let rc = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0)
            }
        }
        guard rc == 0 else { return nil }
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let nanos = Double(info.ri_user_time + info.ri_system_time)
            * Double(timebase.numer) / Double(timebase.denom)
        return ProcessUsage(cpuSeconds: nanos / 1e9, diskBytesRead: info.ri_diskio_bytesread)
    }

    public func delta(since earlier: ProcessUsage) -> Delta {
        let bytes = diskBytesRead >= earlier.diskBytesRead ? diskBytesRead - earlier.diskBytesRead : 0
        return Delta(cpuSeconds: cpuSeconds - earlier.cpuSeconds,
                     diskMegabytesRead: Double(bytes) / 1_048_576)
    }
}
