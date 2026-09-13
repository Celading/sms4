# 构建与消费

需要 Cangjie 1.1.3 STS；从仓库根运行：

```sh
git clone --branch publication/cjku-0.2.0 https://github.com/Celading/sms4.git
cd sms4
cjpm build
cjpm test
```

不需要同项目集其他目录。使用 `cjpm bundle` 生成 target/sms4-0.2.0.cjp，包含源码/测试、公开manual、examples、LICENSE与NOTICE。

仓外消费可使用 Git 依赖，锁定经验证的提交：

```toml
[dependencies]
"CjKu::sms4" = { git = "https://github.com/Celading/sms4.git", branch = "publication/cjku-0.2.0" }
```

首次解析后保留应用的 cjpm.lock；发布应用时建议用 commitId 固定版本。也可克隆到应用自行管理的vendor目录再用path指向它，这不是依赖私有工作区。

验收目前仅覆盖 macOS arm64 / Cangjie 1.1.3。测试运行器需要回环端口；端口权限错误不等于测试通过。Windows/Linux未实机验收。脚本与测试遇错必须非零退出，不把日志过滤结果当成功。
