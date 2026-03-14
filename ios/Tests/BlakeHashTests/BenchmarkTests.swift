import Foundation
import Testing
@testable import BlakeHash

/// Throughput benchmarks for all BLAKE algorithms.
@Suite("Benchmarks", .tags(.benchmark), .serialized)
struct BenchmarkTests {

    static let warmUp = 20
    static let iterations = 100
    static let dataSize = 1024 * 1024 // 1 MB

    static func makeBenchData() -> Data {
        Data((0..<dataSize).map { UInt8($0 % 251) })
    }

    static func benchmark(_ name: String, action: (Data) -> Data) {
        let data = makeBenchData()

        // Warm up
        for _ in 0..<warmUp { _ = action(data) }

        // Timed iterations
        let start = ContinuousClock.now
        for _ in 0..<iterations { _ = action(data) }
        let elapsed = start.duration(to: .now)

        let totalBytes = Double(dataSize) * Double(iterations)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        let mbPerSec = (totalBytes / (1024 * 1024)) / seconds
        let nsPerByte = (seconds * 1e9) / totalBytes

        let paddedName = name.padding(toLength: 20, withPad: " ", startingAt: 0)
        print("BENCH | \(paddedName) | \(String(format: "%8d", dataSize)) bytes | \(String(format: "%8.2f", mbPerSec)) MB/s | \(String(format: "%5.2f", nsPerByte)) ns/byte")
    }

    @Test("BLAKE2b-512") func blake2b512() { Self.benchmark("BLAKE2b-512") { BLAKE2b.hash($0) } }
    @Test("BLAKE2b-256") func blake2b256() { Self.benchmark("BLAKE2b-256") { BLAKE2b.hash($0, digestLength: 32) } }
    @Test("BLAKE2s-256") func blake2s256() { Self.benchmark("BLAKE2s-256") { BLAKE2s.hash($0) } }
    @Test("BLAKE2bp")    func blake2bp()   { Self.benchmark("BLAKE2bp")    { BLAKE2bp.hash($0) } }
    @Test("BLAKE2sp")    func blake2sp()   { Self.benchmark("BLAKE2sp")    { BLAKE2sp.hash($0) } }
    @Test("BLAKE3")      func blake3()     { Self.benchmark("BLAKE3")      { BLAKE3.hash($0) } }
}

extension Tag {
    @Tag static var benchmark: Self
}
