# 示例

[仓外消费源码](../../examples/basic.cj) 使用正式公开API，保存到应用的src/main.cj并按[构建说明](build.md)配置依赖。

```cangjie
package consumer
import sms4.*
main(): Int64 {
    let signer = RpcSigner()
    let query = signer.canonicalQuery([("Action", "SendSms"), ("Version", "2017-05-25")])
    println(signer.stringToSign(query))
    let q = RetryQueue(MockTransport())
    println(q.submit(SmsRequest("test-destination", "test-template")).ok)
    return 0
}
```
