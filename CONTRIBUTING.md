# 参与开发

需要 macOS 14 及以上和 Xcode 15 及以上。

## 编译与运行

```bash
./scripts/build-app.sh
```

编译 release 版（Apple 芯片和 Intel 通用）并签名，安装到 `~/Applications/MacTab.app` 后启动。首次启动要在「系统设置 → 隐私与安全性 → 辅助功能」里授权。

## 代码签名证书（可选）

辅助功能授权绑定在应用的签名上。没有证书时脚本用临时签名，每次重新编译签名都会变，系统当成新应用，需要重新授权。运行一次：

```bash
./scripts/setup-cert.sh
```

会在登录钥匙串里创建自签名证书「MacTab Local」（10 年有效），之后都用它签名，重新编译不用再授权。从临时签名换成证书后，先运行 `tccutil reset Accessibility local.mactab` 清掉旧授权，再重新授权一次。

## 测试与日志

```bash
swift test
/usr/bin/log show --last 2m --style compact --predicate 'subsystem == "local.mactab"'
```

## 效果图

改了主题后，运行 `./scripts/theme-shots.sh` 重新生成 README 里的效果图（需要 ffmpeg）。
