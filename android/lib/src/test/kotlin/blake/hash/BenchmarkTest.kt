package blake.hash

import org.junit.jupiter.api.Tag
import org.junit.jupiter.api.Test

/**
 * Throughput benchmarks for all BLAKE algorithms.
 * Tagged "benchmark" so they can be run separately from unit tests.
 */
@Tag("benchmark")
class BenchmarkTest {

    private val warmUp = 50
    private val iterations = 200
    private val dataSizes = intArrayOf(1024 * 1024) // 1 MB

    private fun ByteArray.toHex(): String =
        joinToString("") { "%02x".format(it) }

    private fun benchmark(name: String, dataSize: Int, action: (ByteArray) -> ByteArray) {
        val data = ByteArray(dataSize) { (it % 251).toByte() }

        // Warm up
        repeat(warmUp) { action(data) }

        // Timed iterations
        val start = System.nanoTime()
        repeat(iterations) { action(data) }
        val elapsed = System.nanoTime() - start

        val totalBytes = dataSize.toLong() * iterations
        val seconds = elapsed / 1_000_000_000.0
        val mbPerSec = (totalBytes / (1024.0 * 1024.0)) / seconds
        val nsPerByte = elapsed.toDouble() / totalBytes

        println("BENCH | %-20s | %8d bytes | %8.2f MB/s | %5.2f ns/byte".format(
            name, dataSize, mbPerSec, nsPerByte
        ))
    }

    @Test fun `benchmark BLAKE2b-512`() {
        for (size in dataSizes) benchmark("BLAKE2b-512", size) { Blake2b.hash(it) }
    }

    @Test fun `benchmark BLAKE2b-256`() {
        for (size in dataSizes) benchmark("BLAKE2b-256", size) { Blake2b.hash(it, digestLength = 32) }
    }

    @Test fun `benchmark BLAKE2s-256`() {
        for (size in dataSizes) benchmark("BLAKE2s-256", size) { Blake2s.hash(it) }
    }

    @Test fun `benchmark BLAKE2bp`() {
        for (size in dataSizes) benchmark("BLAKE2bp", size) { Blake2bp.hash(it) }
    }

    @Test fun `benchmark BLAKE2sp`() {
        for (size in dataSizes) benchmark("BLAKE2sp", size) { Blake2sp.hash(it) }
    }

    @Test fun `benchmark BLAKE3`() {
        for (size in dataSizes) benchmark("BLAKE3", size) { Blake3.hash(it) }
    }
}
