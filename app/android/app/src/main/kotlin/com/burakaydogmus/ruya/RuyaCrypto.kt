package com.burakaydogmus.ruya

import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/** Pure JVM crypto helpers (no Android dependencies, unit-testable). */
object RuyaCrypto {
    /**
     * RFC 8018 PBKDF2 with HMAC-SHA256 over the raw password bytes.
     * Implemented directly on javax.crypto.Mac (instead of SecretKeyFactory) so the
     * password is not re-encoded from a char[] and matches the Dart implementation
     * byte for byte.
     */
    fun pbkdf2Sha256(password: ByteArray, salt: ByteArray, iterations: Int, length: Int): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(password, "HmacSHA256"))
        val hLen = mac.macLength
        val blocks = (length + hLen - 1) / hLen
        val out = ByteArray(length)
        val u = ByteArray(hLen)
        val t = ByteArray(hLen)
        for (block in 1..blocks) {
            mac.update(salt)
            mac.update(
                byteArrayOf(
                    (block ushr 24).toByte(), (block ushr 16).toByte(),
                    (block ushr 8).toByte(), block.toByte()
                )
            )
            mac.doFinal(u, 0)
            System.arraycopy(u, 0, t, 0, hLen)
            for (i in 1 until iterations) {
                mac.update(u)
                mac.doFinal(u, 0)
                for (j in 0 until hLen) t[j] = (t[j].toInt() xor u[j].toInt()).toByte()
            }
            val offset = (block - 1) * hLen
            System.arraycopy(t, 0, out, offset, minOf(hLen, length - offset))
        }
        return out
    }
}
