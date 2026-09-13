package CjKu::sms4
import std.unittest.*
import std.unittest.testmacro.*
@Test
func rpcSignatureIsBase64Digest(): Unit {
    @Assert(RpcSigner().sign("secret", "GET&%2F&Action%3DSendSms") ==
        "kisOkJyGHgexvK2oO+NKrODoY5w=")
}
@Test
func rateLimitedCallDoesNotCountAsAttempt(): Unit {
    let c = FakeClock()
    let b = TokenBucket(1, 1.0, c)
    let q = RetryQueue(MockTransport(), limiter: b)
    @Assert(q.submit(SmsRequest("test", "test")).attempts == 1)
    @Assert(q.submit(SmsRequest("test", "test")).attempts == 0)
}
@Test
func backoffActuallyCallsWaitBetweenAttempts(): Unit {
    let c = FakeClock()
    let q = RetryQueue(MockTransport(failuresBeforeSuccess: 2), waitMs: { ms => c.advance(ms) })
    let r = q.submit(SmsRequest("test", "test"))
    @Assert(r.ok && r.attempts == 3)
    @Assert(c.nowMs() == 300)
    @Assert(q.lastBackoffPlan.toArray() == [100, 200])
}
@Test
func canonicalQuerySortsAndEscapes(): Unit {
    let s = RpcSigner()
    @Assert(s.canonicalQuery([("Z", "a b"), ("A", "+")]) == "A=%2B&Z=a%20b")
    @Assert(s.stringToSign("A=1", method: "POST") == "POST&%2F&A%3D1")
    var duplicate = false
    try { let _ = s.canonicalQuery([("A", "1"), ("A", "2")]) }
    catch (e: IllegalArgumentException) { duplicate = true }
    @Assert(duplicate)
}
