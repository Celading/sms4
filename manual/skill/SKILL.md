---
name: sms4-usage
description: Build, consume and validate sms4 through its public Cangjie API.
---

# sms4 usage

Read [API](../docs/api.md), [build](../docs/build.md) and [limits](../docs/limits.md) before edits. Confirm the exact dependency commit and compiler version. Use examples/basic.cj as an external consumer, not a replacement implementation.

参数规范化 → RPC签名；请求 → 令牌桶 → transport → 失败后等待 → 再尝试。transport拥有网络资源；队列/桶为单调用者可变对象。

Validate ordinary inputs, boundary inputs and errors through the same API. Run cjpm build and cjpm test, retain the actual exit status. Test package contents and a separate consumer after packaging changes. Never remove a failing regression or claim an untested platform.

不自带HTTPS提供商，不保存密钥，不实发短信。SHA-1仅用于兼容已指定的RPC协议，不作新密码设计；详见CRYPTO-NOTICE。同步重试不是持久消息队列；调用者负责幂等、超时、取消、并发同步及提供商错误分类。仅false结果按策略重试，不能据此承诺不重复投递。
