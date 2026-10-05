package com.burakaydogmus.ruya

import org.junit.Assert.assertEquals
import org.junit.Test

class Pbkdf2Test {
    private fun hex(b: ByteArray) = b.joinToString("") { "%02x".format(it) }

    @Test
    fun rfc7914Vector1() {
        val out = RuyaCrypto.pbkdf2Sha256("passwd".toByteArray(), "salt".toByteArray(), 1, 64)
        assertEquals(
            "55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc" +
                "49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783",
            hex(out)
        )
    }

    @Test
    fun rfc7914Vector2() {
        val out = RuyaCrypto.pbkdf2Sha256("Password".toByteArray(), "NaCl".toByteArray(), 80000, 64)
        assertEquals(
            "4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56" +
                "a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d",
            hex(out)
        )
    }

    @Test
    fun shortOutputIsPrefixOfLongOutput() {
        val long = RuyaCrypto.pbkdf2Sha256(byteArrayOf(1, 2, 3), byteArrayOf(4, 5), 10, 64)
        val short = RuyaCrypto.pbkdf2Sha256(byteArrayOf(1, 2, 3), byteArrayOf(4, 5), 10, 32)
        assertEquals(hex(long).substring(0, 64), hex(short))
    }
}
