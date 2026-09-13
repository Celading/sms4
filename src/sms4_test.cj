package sms4

import std.unittest.*
import std.unittest.testmacro.*

func ascii(s: String): Array<UInt8> {
    return s.toArray()
}

@Test
func sha1Rfc3174Vectors(): Unit {
        @Assert(toHex(sha1(ascii("abc"))) == "a9993e364706816aba3e25717850c26c9cd0d89d")
    @Assert(toHex(sha1(ascii(""))) == "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    // 56-byte message: one pad byte forces an extra block
    @Assert(toHex(sha1(ascii("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"))) ==
        "84983e441c3bd26ebaae4aa1f95129e5e54670f1")
}

@Test
func hmacRfc2202Vector(): Unit {
    let d = toHex(hmacSha1(ascii("key"),
        ascii("The quick brown fox jumps over the lazy dog")))
    @Assert(d == "de7c9b85b8b78aa6bc8a7a36f70a90701c9db4d9")
    // RFC 2202 case 1: key 20 bytes of 0x0b, data "Hi There"
    var k = Array<UInt8>(20, repeat: 0x0b)
    @Assert(toHex(hmacSha1(k, ascii("Hi There"))) == "b617318655057264e28bc0b6fb378c8ef146be00")
}

@Test
func base64Rfc4648Vectors(): Unit {
    @Assert(base64(ascii("")) == "")
    @Assert(base64(ascii("f")) == "Zg==")
    @Assert(base64(ascii("fo")) == "Zm8=")
    @Assert(base64(ascii("foo")) == "Zm9v")
    @Assert(base64(ascii("Man")) == "TWFu")
}

@Test
func percentEncodeFollowsRfc3986(): Unit {
    @Assert(percentEncode("a-z_9.~") == "a-z_9.~")
    @Assert(percentEncode("a b") == "a%20b")
    @Assert(percentEncode("k=v&x") == "k%3Dv%26x")
    @Assert(percentEncode("+") == "%2B")
}

@Test
func stringToSignShape(): Unit {
    let signer = RpcSigner()
    let sts = signer.stringToSign("AccessKeyId=test&Action=SendSms")
    @Assert(starsStart(sts))
    @Assert(sts.contains("%2F"))
}

func starsStart(s: String): Bool {
    return s.startsWith("GET&")
}

@Test
func rateLimitRefillsOverTime(): Unit {
    let clock = FakeClock()
    let bucket = TokenBucket(2, 1.0, clock) // 1 token/s, capacity 2
    @Assert(bucket.tryTake())
    @Assert(bucket.tryTake())
    @Assert(!bucket.tryTake())
    clock.advance(1000)
    @Assert(bucket.tryTake())
    @Assert(!bucket.tryTake())
}

@Test
func retryQueueIsHonestAboutAttempts(): Unit {
    let t = MockTransport(failuresBeforeSuccess: 2)
    let q = RetryQueue(t, maxAttempts: 3, baseBackoffMs: 100)
    @Assert(q.lastBackoffPlan.size >= 0)
    let r = q.submit(SmsRequest("13800138000", "SMS_123"))
    @Assert(r.ok)
    @Assert(r.attempts == 3)
    let dead = RetryQueue(MockTransport(failuresBeforeSuccess: 99),
        maxAttempts: 3, baseBackoffMs: 100)
    let f = dead.submit(SmsRequest("13800138000", "SMS_123"))
    @Assert(!f.ok)
    @Assert(f.attempts == 3)
}

// Boundary regressions.

@Test
func subUnitRateStillRefills(): Unit {
    // S1: 0.5 tokens/s used to truncate to 0 refill — permanent shutdown
    let c = FakeClock()
    let b = TokenBucket(10, 0.5, c)
    var taken: Int64 = 0
    while (b.tryTake()) { taken += 1 }
    c.advance(60000) // 30 tokens' worth at 0.5/s, capped at capacity 10
    while (b.tryTake()) { taken += 1 }
    @Assert(taken == 20)
}

@Test
func backoffPlanIsBoundedForHugeAttemptCounts(): Unit {
    // S2: maxAttempts=80 used to overflow Int64 with raw shifts
    let t = MockTransport(failuresBeforeSuccess: 1000)
    let q = RetryQueue(t, maxAttempts: 80, baseBackoffMs: 1000, waitMs: { _ => () })
    let r = q.submit(SmsRequest("13800138000", "SMS_1"))
    @Assert(!r.ok)
    @Assert(q.lastBackoffPlan.size == 79)
    var bounded = true
    for (d in q.lastBackoffPlan) {
        if (d > 60000) { bounded = false }
    }
    @Assert(bounded)
}

@Test
func limiterBlocksSendWhenBucketEmpty(): Unit {
    // S3: the queue consults the limiter before every send
    let c = FakeClock()
    let limiter = TokenBucket(1, 0.001, c)
    let t = MockTransport(failuresBeforeSuccess: 0)
    let q = RetryQueue(t, maxAttempts: 3, limiter: limiter)
    let r1 = q.submit(SmsRequest("13800138000", "SMS_1"))
    @Assert(r1.ok) // first token consumed
    let r2 = q.submit(SmsRequest("13800138001", "SMS_1"))
    @Assert(!r2.ok)
    @Assert(r2.message.contains("rate limited"))
}

// Boundary regressions.

@Test
func microRateKeepsRefilling(): Unit {
    // F02: 0.0001 token/s quantized to zero refill then fabricated infinite
    // tokens; the fractional remainder must survive
    let c = FakeClock()
    let b = TokenBucket(1, 0.0001, c)
    @Assert(b.tryTake()) // drain the single initial token
    @Assert(!b.tryTake())
    c.advance(10000000) // 0.0001/s -> one token takes 10000 seconds
    @Assert(b.tryTake())
    @Assert(!b.tryTake())
}

@Test
func oneMsAdvanceWithRemainderIsSafe(): Unit {
    // F02: capacity 2 with 1 token left, advance 1ms — the old integer
    // accumulator threw OverflowException:add
    let c = FakeClock()
    let b = TokenBucket(2, 0.0001, c)
    @Assert(b.tryTake())
    @Assert(b.tryTake()) // both initial tokens consumed
    @Assert(!b.tryTake())
    c.advance(1) // 0.0001 milli-tokens — sub-token, must not overflow
    @Assert(!b.tryTake())
}

@Test
func nonFiniteAndZeroRatesAreRejected(): Unit {
    var z = false
    try { let _ = TokenBucket(1, 0.0, FakeClock()) } catch (e: IllegalArgumentException) { z = true }
    @Assert(z)
    var nan = false
    try { let _ = TokenBucket(1, 0.0/0.0, FakeClock()) } catch (e: IllegalArgumentException) { nan = true }
    @Assert(nan)
}
