package CjKu::sms4

import std.collection.ArrayList

// RFC 3986 percent-encoding (unreserved = A-Z a-z 0-9 - _ . ~) and
// Base64 (RFC 4648). Aliyun-style RPC signing composes them:
// StringToSign = "GET&%2F&" + percentEncode(canonicalQuery).

public func percentEncode(s: String): String {
    const hexd: String = "0123456789ABCDEF"
    let out = ArrayList<UInt8>()
    for (b in s.toArray()) {
        let c = Int64(b)
        if ((b >= 65 && b <= 90) || (b >= 97 && b <= 122) ||
            (b >= 48 && b <= 57) || b == 45 || b == 95 || b == 46 || b == 126) {
            out.add(b)
        } else {
            out.add(37) // '%'
            out.add(hexd[c >> 4])
            out.add(hexd[c & 0xF])
        }
    }
    return String.fromUtf8(out.toArray())
}

public func base64(data: Array<UInt8>): String {
    const tbl: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    let out = ArrayList<UInt8>()
    let n = Int64(data.size)
    var i: Int64 = 0
    while (i + 3 <= n) {
        let v = (Int64(data[i]) << 16) | (Int64(data[i + 1]) << 8) | Int64(data[i + 2])
        out.add(tbl[(v >> 18) & 63])
        out.add(tbl[(v >> 12) & 63])
        out.add(tbl[(v >> 6) & 63])
        out.add(tbl[v & 63])
        i += 3
    }
    let rem = n - i
    if (rem == 1) {
        let v = Int64(data[i]) << 16
        out.add(tbl[(v >> 18) & 63])
        out.add(tbl[(v >> 12) & 63])
        out.add(61) // '='
        out.add(61)
    } else if (rem == 2) {
        let v = (Int64(data[i]) << 16) | (Int64(data[i + 1]) << 8)
        out.add(tbl[(v >> 18) & 63])
        out.add(tbl[(v >> 12) & 63])
        out.add(tbl[(v >> 6) & 63])
        out.add(61)
    }
    return String.fromUtf8(out.toArray())
}

public class RpcSigner {
    public init() {}

    public func canonicalQuery(params: Array<(String, String)>): String {
        let sorted = ArrayList<(String, String)>()
        for ((k, v) in params) {
            if (k.isEmpty() || k == "Signature") {
                throw IllegalArgumentException("RPC signing requires nonempty parameter names and excludes Signature")
            }
            for ((previous, _) in sorted) {
                if (previous == k) { throw IllegalArgumentException("duplicate RPC parameter") }
            }
            sorted.add((k, v))
        }
        var i: Int64 = 1
        while (i < sorted.size) {
            var j = i
            while (j > 0 && sorted[j][0] < sorted[j - 1][0]) {
                let value = sorted[j]
                sorted[j] = sorted[j - 1]
                sorted[j - 1] = value
                j -= 1
            }
            i += 1
        }
        let out = StringBuilder()
        var first = true
        for ((k, v) in sorted) {
            if (!first) { out.append("&") }
            first = false
            out.append(percentEncode(k) + "=" + percentEncode(v))
        }
        return out.toString()
    }

    // canonicalQuery: "k=v&k=v" with values percent-encoded after sort
    public func stringToSign(canonicalQuery: String, method!: String = "GET"): String {
        if (method != "GET" && method != "POST") {
            throw IllegalArgumentException("RPC method must be GET or POST")
        }
        return method + "&" + percentEncode("/") + "&" + percentEncode(canonicalQuery)
    }

    public func sign(secret: String, stringToSign: String): String {
        return base64(hmacSha1((secret + "&").toArray(), stringToSign.toArray()))
    }
}
