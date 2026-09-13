# sms4

短信 RPC 签名、令牌桶限流与有真实等待的可插拔重试通路。

Version 0.2.0 · Cangjie 1.1.3 · Apache-2.0

## 快速开始

```sh
git clone https://github.com/Celading/sms4.git
cd sms4
cjpm build
cjpm test
```

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

[接入与打包](manual/docs/build.md) · [API](manual/docs/api.md) · [边界](manual/docs/limits.md) · [使用工作流](manual/skill/SKILL.md)

## 能力边界

不自带HTTPS提供商，不保存密钥，不实发短信。SHA-1仅用于兼容已指定的RPC协议，不作新密码设计；详见CRYPTO-NOTICE。同步重试不是持久消息队列；调用者负责幂等、超时、取消、并发同步及提供商错误分类。仅false结果按策略重试，不能据此承诺不重复投递。

## License

见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)。当前为源码发行，未声明中心仓上架或全平台认证。
