package CjKu::sms4

import std.collection.ArrayList
import std.collection.HashMap

// ---- models ----

public class SmsRequest {
    public let phone: String
    public let templateCode: String
    public let params: ArrayList<(String, String)>
    public init(phone: String, templateCode: String) {
        this.phone = phone
        this.templateCode = templateCode
        params = ArrayList<(String, String)>()
    }
    public func addParam(k: String, v: String): Unit {
        params.add((k, v))
    }
}

public class SmsResult {
    public let ok: Bool
    public let providerRef: String
    public let message: String
    public let attempts: Int64
    public init(ok: Bool, providerRef: String, message: String, attempts: Int64) {
        this.ok = ok
        this.providerRef = providerRef
        this.message = message
        this.attempts = attempts
    }
}

// ---- transport (live HTTPS is behind the TLS fence; see plan) ----

public interface SmsTransport {
    func send(req: SmsRequest): SmsResult
}

public class MockTransport <: SmsTransport {
    let script: ArrayList<(Int64, Bool)>  // (failuresBeforeSuccess, ok)
    var calls: Int64 = 0
    public init(failuresBeforeSuccess!: Int64 = 0) {
        script = ArrayList<(Int64, Bool)>()
        script.add((failuresBeforeSuccess, true))
    }
    public func send(req: SmsRequest): SmsResult {
        calls += 1
        let (fails, ok) = script[0]
        if (calls <= fails) {
            return SmsResult(false, "", "transient failure " + calls.toString(), calls)
        }
        return SmsResult(ok, "mock-" + req.phone, "accepted", calls)
    }
}

// ---- rate limiting: token bucket on an injectable clock ----

public interface Clock {
    func nowMs(): Int64
}

public class FakeClock <: Clock {
    public var t: Int64 = 0
    public init() {}
    public func nowMs(): Int64 { t }
    public func advance(ms: Int64): Unit { t += ms }
}

public class TokenBucket {
    // F02: fractional remainder is KEPT in Float64 milli-tokens — integer
    // quantization (milli then micro) still truncates 0.0001 t/s to a zero
    // refill, and the zero branch then fabricated an infinite refill
    let capacity: Int64
    let rateMilliPerMs: Float64 // milli-tokens per ms equals tokens per second
    var tokensMilli: Float64
    var last: Int64
    let clock: Clock

    public init(capacity: Int64, tokensPerSecond: Float64, clock: Clock) {
        if (capacity <= 0 || capacity > 1000000) {
            throw IllegalArgumentException("TokenBucket: capacity must be 1..1000000 tokens")
        }
        // zero/negative/non-finite rates are caller errors, never "no refill"
        if (tokensPerSecond <= 0.0 || tokensPerSecond != tokensPerSecond ||
            tokensPerSecond == Float64.Inf) {
            throw IllegalArgumentException("TokenBucket: tokensPerSecond must be finite and positive")
        }
        this.capacity = capacity
        // 1 token/s == 1 milli-token/ms, so the rate carries over as-is
        this.rateMilliPerMs = tokensPerSecond
        this.tokensMilli = Float64(capacity) * 1000.0
        this.last = clock.nowMs()
        this.clock = clock
    }

    public func tryTake(): Bool {
        let now = clock.nowMs()
        if (now > last) {
            let el = Float64(now) - Float64(last)
            // Float64 saturates to +inf on huge spans; clamp BEFORE adding
            // so the accumulator can never overflow or fabricate tokens
            let capMilli = Float64(capacity) * 1000.0
            let add = el * rateMilliPerMs
            if (add >= capMilli - tokensMilli) {
                tokensMilli = capMilli
            } else {
                tokensMilli += add
            }
            last = now
        }
        if (tokensMilli >= 1000.0) {
            tokensMilli -= 1000.0
            return true
        }
        return false
    }
}

// ---- retry queue: exponential backoff, honest attempt accounting ----

public class RetryQueue {
    let transport: SmsTransport
    let maxAttempts: Int64
    let baseBackoffMs: Int64
    let waitMs: (Int64) -> Unit
    // S3: when wired, every send must first take a token from the bucket —
    // refusals surface as an explicit rate-limited result instead of the
    // queue hammering the transport
    public let limiter: ?TokenBucket
    public static const MAX_BACKOFF_MS: Int64 = 60000
    // Delays requested from the wait callback by the last submit.
    public var lastBackoffPlan: ArrayList<Int64> = ArrayList<Int64>()

    public init(transport: SmsTransport, maxAttempts!: Int64 = 3,
        baseBackoffMs!: Int64 = 100, limiter!: ?TokenBucket = None,
        waitMs!: (Int64) -> Unit = { ms => sleep(ms * Duration.millisecond) }) {
        if (maxAttempts < 1 || baseBackoffMs < 0) {
            throw IllegalArgumentException("RetryQueue: attempts must be positive and backoff non-negative")
        }
        this.transport = transport
        this.maxAttempts = maxAttempts
        this.baseBackoffMs = baseBackoffMs
        this.limiter = limiter
        this.waitMs = waitMs
    }

    // S2: exponential with a hard 60s ceiling — the old raw shift overflowed
    // Int64 for maxAttempts >= 59
    func backoffFor(attempt: Int64): Int64 {
        var delay = baseBackoffMs
        var k: Int64 = 1
        while (k < attempt && delay < MAX_BACKOFF_MS) {
            delay *= 2
            if (delay > MAX_BACKOFF_MS) { delay = MAX_BACKOFF_MS }
            k += 1
        }
        if (delay > MAX_BACKOFF_MS) { delay = MAX_BACKOFF_MS }
        delay
    }

    public func submit(req: SmsRequest): SmsResult {
        var attempt: Int64 = 0
        var last = SmsResult(false, "", "no attempt", 0)
        lastBackoffPlan = ArrayList<Int64>()
        while (attempt < maxAttempts) {
            match (limiter) {
                case Some(b) =>
                    if (!b.tryTake()) {
                        return SmsResult(false, "", "rate limited by gateway token bucket", attempt)
                    }
                case None => ()
            }
            attempt += 1
            last = transport.send(req)
            if (last.ok) {
                return SmsResult(true, last.providerRef, last.message, attempt)
            }
            if (attempt < maxAttempts) {
                let delay = backoffFor(attempt)
                lastBackoffPlan.add(delay)
                waitMs(delay)
            }
        }
        return SmsResult(false, "", last.message, attempt)
    }
}
