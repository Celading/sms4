# 数据与错误

`RpcSigner.canonicalQuery(params)` 按参数名排序并RFC3986编码；拒绝空名称、重复名称和Signature字段。`stringToSign(query, method: "GET")` 支持GET/POST；`sign(secret, stringToSign)` 返回Base64 HMAC-SHA1，密钥为secret加&，调用者在URL中再次编码Signature。

`sha1` / `hmacSha1` 返回原始字节；`toHex` / `base64` / `percentEncode` 为编码工具。

`SmsRequest(phone,templateCode)` + addParam，`SmsTransport.send(req)` 返回 SmsResult(ok,providerRef,message,attempts)。`MockTransport` 为确定性测试替身，不发短信。

`Clock.nowMs` 是调用者注入时钟；`TokenBucket(capacity, tokensPerSecond, clock)` 支持分数速率，容量1..1000000、速率有限正数，回退时钟不增发，tryTake消耗1个令牌。

`RetryQueue(transport, maxAttempts:3, baseBackoffMs:100, limiter:None, waitMs:...)` 在失败尝试间真实sleep，退避封顶60000ms。可注入等待器接入宿主或确定性测试。attempts仅计实际send调用；限流拒绝不计一次send。传输或等待器抛出的异常原样传播，不偷偷重试未知异常。

不自带HTTPS提供商，不保存密钥，不实发短信。SHA-1仅用于兼容已指定的RPC协议，不作新密码设计；详见CRYPTO-NOTICE。同步重试不是持久消息队列；调用者负责幂等、超时、取消、并发同步及提供商错误分类。仅false结果按策略重试，不能据此承诺不重复投递。
