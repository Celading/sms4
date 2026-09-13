# Boundaries

不自带HTTPS提供商，不保存密钥，不实发短信。SHA-1仅用于兼容已指定的RPC协议，不作新密码设计；详见CRYPTO-NOTICE。同步重试不是持久消息队列；调用者负责幂等、超时、取消、并发同步及提供商错误分类。仅false结果按策略重试，不能据此承诺不重复投递。

Read [public API](../docs/api.md). Do not infer network, cryptographic certification or platform support from compilation.
