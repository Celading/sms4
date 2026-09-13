<p align="center">
 <img src="https://img.shields.io/badge/Cangjie-sms4-ff6b35?style=for-the-badge&labelColor=1a1a2e" alt="sms4" />
 <img src="https://img.shields.io/badge/version-0.2.0-blue?style=for-the-badge&labelColor=1a1a2e" alt="Version" />
 <img src="https://img.shields.io/badge/license-Apache%202.0-green?style=for-the-badge&labelColor=1a1a2e" alt="License" />
</p>

<div align="center">
<span style="font-weight:300;font-size:38px">sms4</span><br/>
<span style="font-weight:100;font-size:26px">短信 RPC 签名、令牌桶限流与有真实等待的可插拔重试通路</span>
<p align="center">
 <sub>RPC 签名 · 令牌桶 · 可插拔传输 · 同步重试</sub>
</p>
</div>

<p align="center">
 <a href="https://github.com/Celading/sms4">开源主仓</a> ·
 <a href="https://github.com/Celading/sms4/blob/publication/cjku-0.2.0/manual/docs/build.md">接入指南</a>
</p>

> 当前文档对应版本：`0.2.0` · Cangjie `1.1.3`

## 快速开始

```toml
[dependencies]
"CjKu::sms4" = "0.2.0"
```

也可构建本组织分支源码：

```sh
git clone --branch publication/cjku-0.2.0 https://github.com/Celading/sms4.git
cd sms4
cjpm build
cjpm test
```

```cangjie
package consumer
import CjKu::sms4.*
main(): Int64 {
    let signer = RpcSigner()
    let query = signer.canonicalQuery([("Action", "SendSms"), ("Version", "2017-05-25")])
    println(signer.stringToSign(query))
    let q = RetryQueue(MockTransport())
    println(q.submit(SmsRequest("test-destination", "test-template")).ok)
    return 0
}
```

[接入与打包](https://github.com/Celading/sms4/blob/publication/cjku-0.2.0/manual/docs/build.md) · [API](https://github.com/Celading/sms4/blob/publication/cjku-0.2.0/manual/docs/api.md) · [边界](https://github.com/Celading/sms4/blob/publication/cjku-0.2.0/manual/docs/limits.md) · [使用工作流](https://github.com/Celading/sms4/blob/publication/cjku-0.2.0/manual/skill/SKILL.md)

## 能力边界

不自带HTTPS提供商，不保存密钥，不实发短信。SHA-1仅用于兼容已指定的RPC协议，不作新密码设计；详见CRYPTO-NOTICE。同步重试不是持久消息队列；调用者负责幂等、超时、取消、并发同步及提供商错误分类。仅false结果按策略重试，不能据此承诺不重复投递。

## License

见 [LICENSE](https://github.com/Celading/sms4/blob/publication/cjku-0.2.0/LICENSE) 与 [NOTICE](https://github.com/Celading/sms4/blob/publication/cjku-0.2.0/NOTICE)。本分支用于 CjKu 组织发行；不声明全平台认证。
