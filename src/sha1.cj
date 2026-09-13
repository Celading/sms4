package sms4

import std.collection.ArrayList

// SHA-1 (RFC 3174) and HMAC-SHA1 (RFC 2104), written out in Int64 with
// explicit masks because Cangjie debug builds throw on integer overflow.
// Goldens: RFC 3174 ("abc"), RFC 2202 (HMAC), RFC 4648 (base64).

func rotl32(x: Int64, n: Int64): Int64 {
    let m = x & 0xFFFFFFFF
    return ((m << n) | (m >> (32 - n))) & 0xFFFFFFFF
}

public func sha1(data: Array<UInt8>): Array<UInt8> {
    var h0: Int64 = 0x67452301
    var h1: Int64 = 0xEFCDAB89
    var h2: Int64 = 0x98BADCFE
    var h3: Int64 = 0x10325476
    var h4: Int64 = 0xC3D2E1F0
    let n = Int64(data.size)
    let bitLen = n * 8
    var msg = ArrayList<UInt8>()
    for (b in data) { msg.add(b) }
    msg.add(0x80)
    while (msg.size % 64 != 56) {
        msg.add(0)
    }
    var i: Int64 = 7
    while (i >= 0) {
        msg.add(UInt8((bitLen >> (i * 8)) & 0xFF))
        i -= 1
    }
    let blocks = Int64(msg.size) / 64
    var w = Array<Int64>(80, repeat: 0)
    var bi: Int64 = 0
    while (bi < blocks) {
        var t: Int64 = 0
        while (t < 16) {
            let o = bi * 64 + t * 4
            w[t] = (Int64(msg[o]) << 24) | (Int64(msg[o + 1]) << 16) |
                (Int64(msg[o + 2]) << 8) | Int64(msg[o + 3])
            t += 1
        }
        t = 16
        while (t < 80) {
            let x = w[t - 3] ^ w[t - 8] ^ w[t - 14] ^ w[t - 16]
            w[t] = ((x << 1) | (x >> 31)) & 0xFFFFFFFF
            t += 1
        }
        var a = h0
        var b = h1
        var c = h2
        var d = h3
        var e = h4
        t = 0
        while (t < 80) {
            var f: Int64 = 0
            var k: Int64 = 0
            if (t < 20) {
                f = (b & c) | ((b ^ 0xFFFFFFFF) & d)
                k = 0x5A827999
            } else if (t < 40) {
                f = b ^ c ^ d
                k = 0x6ED9EBA1
            } else if (t < 60) {
                f = (b & c) | (b & d) | (c & d)
                k = 0x8F1BBCDC
            } else {
                f = b ^ c ^ d
                k = 0xCA62C1D6
            }
            let tmp = (rotl32(a, 5) + f + e + k + w[t]) & 0xFFFFFFFF
            e = d
            d = c
            c = rotl32(b, 30)
            b = a
            a = tmp
            t += 1
        }
        h0 = (h0 + a) & 0xFFFFFFFF
        h1 = (h1 + b) & 0xFFFFFFFF
        h2 = (h2 + c) & 0xFFFFFFFF
        h3 = (h3 + d) & 0xFFFFFFFF
        h4 = (h4 + e) & 0xFFFFFFFF
        bi += 1
    }
    let out = Array<UInt8>(20, repeat: 0)
    let hs = [h0, h1, h2, h3, h4]
    i = 0
    while (i < 5) {
        out[i * 4] = UInt8((hs[i] >> 24) & 0xFF)
        out[i * 4 + 1] = UInt8((hs[i] >> 16) & 0xFF)
        out[i * 4 + 2] = UInt8((hs[i] >> 8) & 0xFF)
        out[i * 4 + 3] = UInt8(hs[i] & 0xFF)
        i += 1
    }
    return out
}

public func hmacSha1(key: Array<UInt8>, data: Array<UInt8>): Array<UInt8> {
    var k = Array<UInt8>(64, repeat: 0)
    var i: Int64 = 0
    if (key.size > 64) {
        let h = sha1(key)
        while (i < 20) { k[i] = h[i]; i += 1 }
    } else {
        while (i < key.size) { k[i] = key[i]; i += 1 }
    }
    var ipad = ArrayList<UInt8>()
    var opad = ArrayList<UInt8>()
    i = 0
    while (i < 64) {
        ipad.add(k[i] ^ 0x36)
        opad.add(k[i] ^ 0x5C)
        i += 1
    }
    for (b in data) { ipad.add(b) }
    for (b in sha1(ipad.toArray())) { opad.add(b) }
    return sha1(opad.toArray())
}

public func toHex(b: Array<UInt8>): String {
    const digits: String = "0123456789abcdef"
    let out = Array<UInt8>(b.size * 2, repeat: 0)
    var i: Int64 = 0
    while (i < Int64(b.size)) {
        out[i * 2] = digits[Int64(b[i] >> 4)]
        out[i * 2 + 1] = digits[Int64(b[i] & 0xF)]
        i += 1
    }
    return String.fromUtf8(out)
}
