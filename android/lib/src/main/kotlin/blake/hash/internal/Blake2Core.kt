package blake.hash.internal

import java.lang.invoke.MethodHandles
import java.nio.ByteOrder

// VarHandle-based LE loading — compiles to single unaligned load/store on LE platforms
@JvmField internal val LONG_LE = MethodHandles.byteArrayViewVarHandle(LongArray::class.java, ByteOrder.LITTLE_ENDIAN)
@JvmField internal val INT_LE = MethodHandles.byteArrayViewVarHandle(IntArray::class.java, ByteOrder.LITTLE_ENDIAN)

// Flattened SIGMA permutation schedule for BLAKE2.
// Indexed as SIGMA_FLAT[(round % 10) * 16 + i] — eliminates nested array indirection.
@JvmField
internal val SIGMA_FLAT = intArrayOf(
     0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15,
    14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3,
    11,  8, 12,  0,  5,  2, 15, 13, 10, 14,  3,  6,  7,  1,  9,  4,
     7,  9,  3,  1, 13, 12, 11, 14,  2,  6,  5, 10,  4,  0, 15,  8,
     9,  0,  5,  7,  2,  4, 10, 15, 14,  1, 11, 12,  6,  8,  3, 13,
     2, 12,  6, 10,  0, 11,  8,  3,  4, 13,  7,  5, 15, 14,  1,  9,
    12,  5,  1, 15, 14, 13,  4, 10,  0,  7,  6,  3,  9,  2,  8, 11,
    13, 11,  7, 14, 12,  1,  3,  9,  5,  0, 15,  4,  8,  6,  2, 10,
     6, 15, 14,  9, 11,  3,  0,  8, 12,  2, 13,  7,  1,  4, 10,  5,
    10,  2,  8,  4,  7,  6,  1,  5, 15, 11,  9, 14,  3, 12, 13,  0,
)

// ---- Little-endian 64-bit (BLAKE2b) ----

internal fun loadLong(src: ByteArray, off: Int): Long = LONG_LE.get(src, off) as Long

internal fun storeLong(value: Long, dst: ByteArray, off: Int) { LONG_LE.set(dst, off, value) }

// ---- Little-endian 32-bit (BLAKE2s) ----

internal fun loadInt(src: ByteArray, off: Int): Int = INT_LE.get(src, off) as Int

internal fun storeInt(value: Int, dst: ByteArray, off: Int) { INT_LE.set(dst, off, value) }
