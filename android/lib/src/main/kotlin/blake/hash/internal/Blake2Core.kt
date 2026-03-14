package blake.hash.internal

internal val SIGMA = arrayOf(
    intArrayOf( 0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15),
    intArrayOf(14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3),
    intArrayOf(11,  8, 12,  0,  5,  2, 15, 13, 10, 14,  3,  6,  7,  1,  9,  4),
    intArrayOf( 7,  9,  3,  1, 13, 12, 11, 14,  2,  6,  5, 10,  4,  0, 15,  8),
    intArrayOf( 9,  0,  5,  7,  2,  4, 10, 15, 14,  1, 11, 12,  6,  8,  3, 13),
    intArrayOf( 2, 12,  6, 10,  0, 11,  8,  3,  4, 13,  7,  5, 15, 14,  1,  9),
    intArrayOf(12,  5,  1, 15, 14, 13,  4, 10,  0,  7,  6,  3,  9,  2,  8, 11),
    intArrayOf(13, 11,  7, 14, 12,  1,  3,  9,  5,  0, 15,  4,  8,  6,  2, 10),
    intArrayOf( 6, 15, 14,  9, 11,  3,  0,  8, 12,  2, 13,  7,  1,  4, 10,  5),
    intArrayOf(10,  2,  8,  4,  7,  6,  1,  5, 15, 11,  9, 14,  3, 12, 13,  0)
)

// ---- Little-endian 64-bit (BLAKE2b) ----

internal fun loadLong(src: ByteArray, off: Int): Long =
    (src[off].toLong() and 0xFFL) or
    ((src[off + 1].toLong() and 0xFFL) shl 8) or
    ((src[off + 2].toLong() and 0xFFL) shl 16) or
    ((src[off + 3].toLong() and 0xFFL) shl 24) or
    ((src[off + 4].toLong() and 0xFFL) shl 32) or
    ((src[off + 5].toLong() and 0xFFL) shl 40) or
    ((src[off + 6].toLong() and 0xFFL) shl 48) or
    ((src[off + 7].toLong() and 0xFFL) shl 56)

internal fun storeLong(value: Long, dst: ByteArray, off: Int) {
    dst[off]     = (value).toByte()
    dst[off + 1] = (value ushr 8).toByte()
    dst[off + 2] = (value ushr 16).toByte()
    dst[off + 3] = (value ushr 24).toByte()
    dst[off + 4] = (value ushr 32).toByte()
    dst[off + 5] = (value ushr 40).toByte()
    dst[off + 6] = (value ushr 48).toByte()
    dst[off + 7] = (value ushr 56).toByte()
}

// ---- Little-endian 32-bit (BLAKE2s) ----

internal fun loadInt(src: ByteArray, off: Int): Int =
    (src[off].toInt() and 0xFF) or
    ((src[off + 1].toInt() and 0xFF) shl 8) or
    ((src[off + 2].toInt() and 0xFF) shl 16) or
    ((src[off + 3].toInt() and 0xFF) shl 24)

internal fun storeInt(value: Int, dst: ByteArray, off: Int) {
    dst[off]     = (value).toByte()
    dst[off + 1] = (value ushr 8).toByte()
    dst[off + 2] = (value ushr 16).toByte()
    dst[off + 3] = (value ushr 24).toByte()
}
