package blake.hash

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*

class Blake2Test {

    private fun ByteArray.hex(): String = joinToString("") { "%02x".format(it) }

    // ========================== BLAKE2b ==========================

    @Test fun `BLAKE2b-512 empty`() {
        assertEquals(
            "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419" +
            "d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce",
            Blake2b.hash(ByteArray(0)).hex()
        )
    }

    @Test fun `BLAKE2b-512 abc`() {
        assertEquals(
            "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d1" +
            "7d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923",
            Blake2b.hash("abc".toByteArray()).hex()
        )
    }

    @Test fun `BLAKE2b-256 abc`() {
        assertEquals(
            "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319",
            Blake2b.hash("abc".toByteArray(), digestLength = 32).hex()
        )
    }

    @Test fun `BLAKE2b streaming matches one-shot`() {
        val oneShot = Blake2b.hash("abc".toByteArray())
        val streamed = Blake2b.Hasher()
            .update("a".toByteArray())
            .update("bc".toByteArray())
            .finalize()
        assertArrayEquals(oneShot, streamed)
    }

    // Official KAT: key = 000102…3f, input = empty
    @Test fun `BLAKE2b keyed empty`() {
        val key = ByteArray(64) { it.toByte() }
        assertEquals(
            "10ebb67700b1868efb4417987acf4690ae9d972fb7a590c2f02871799aaa4786" +
            "b5e996e8f0f4eb981fc214b005f42d2ff4233499391653df7aefcbc13fc51568",
            Blake2b.hash(ByteArray(0), key = key).hex()
        )
    }

    // Official KAT: key = 000102…3f, input = 0x00
    @Test fun `BLAKE2b keyed 0x00`() {
        val key = ByteArray(64) { it.toByte() }
        assertEquals(
            "961f6dd1e4dd30f63901690c512e78e4b45e4742ed197c3c5e45c549fd25f2e4" +
            "187b0bc9fe30492b16b0d0bc4ef9b0f34c7003fac09a5ef1532e69430234cebd",
            Blake2b.hash(byteArrayOf(0x00), key = key).hex()
        )
    }

    // ========================== BLAKE2s ==========================

    @Test fun `BLAKE2s-256 empty`() {
        assertEquals(
            "69217a3079908094e11121d042354a7c1f55b6482ca1a51e1b250dfd1ed0eef9",
            Blake2s.hash(ByteArray(0)).hex()
        )
    }

    @Test fun `BLAKE2s-256 abc`() {
        assertEquals(
            "508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982",
            Blake2s.hash("abc".toByteArray()).hex()
        )
    }

    @Test fun `BLAKE2s streaming matches one-shot`() {
        val oneShot = Blake2s.hash("abc".toByteArray())
        val streamed = Blake2s.Hasher()
            .update("a".toByteArray())
            .update("bc".toByteArray())
            .finalize()
        assertArrayEquals(oneShot, streamed)
    }

    @Test fun `BLAKE2s keyed empty`() {
        val key = ByteArray(32) { it.toByte() }
        assertEquals(
            "48a8997da407876b3d79c0d92325ad3b89cbb754d86ab71aee047ad345fd2c49",
            Blake2s.hash(ByteArray(0), key = key).hex()
        )
    }

    // ========================== BLAKE2bp ==========================

    // Official KAT: key = 000102…3f, input = empty
    @Test fun `BLAKE2bp keyed empty`() {
        val key = ByteArray(64) { it.toByte() }
        assertEquals(
            "9d9461073e4eb640a255357b839f394b838c6ff57c9b686a3f76107c1066728f" +
            "3c9956bd785cbc3bf79dc2ab578c5a0c063b9d9c405848de1dbe821cd05c940a",
            Blake2bp.hash(ByteArray(0), key = key).hex()
        )
    }

    // Official KAT: key = 000102…3f, input = 0x00
    @Test fun `BLAKE2bp keyed 0x00`() {
        val key = ByteArray(64) { it.toByte() }
        assertEquals(
            "ff8e90a37b94623932c59f7559f26035029c376732cb14d41602001cbb73adb7" +
            "9293a2dbda5f60703025144d158e2735529596251c73c0345ca6fccb1fb1e97e",
            Blake2bp.hash(byteArrayOf(0x00), key = key).hex()
        )
    }

    // ========================== BLAKE2sp ==========================

    // Official KAT: key = 000102…1f, input = empty
    @Test fun `BLAKE2sp keyed empty`() {
        val key = ByteArray(32) { it.toByte() }
        assertEquals(
            "715cb13895aeb678f6124160bff21465b30f4f6874193fc851b4621043f09cc6",
            Blake2sp.hash(ByteArray(0), key = key).hex()
        )
    }

    // Official KAT: key = 000102…1f, input = 0x00
    @Test fun `BLAKE2sp keyed 0x00`() {
        val key = ByteArray(32) { it.toByte() }
        assertEquals(
            "40578ffa52bf51ae1866f4284d3a157fc1bcd36ac13cbdcb0377e4d0cd0b6603",
            Blake2sp.hash(byteArrayOf(0x00), key = key).hex()
        )
    }
}
