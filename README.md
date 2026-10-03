# MacTab

替代 macOS 的 Cmd+Tab。外观和行为仿照系统切换器，但不显示没有任何窗口的应用（比如关掉所有窗口的访达）。
只要应用还有窗口，就会显示，包括最小化的、被隐藏的、以及窗口在其他桌面上的。

## 效果预览

在设置里选择选中效果主题：

<table>
  <tr>
    <td align="center"><img src="docs/images/themes/classic.gif" width="240" alt="经典"><br>经典</td>
    <td align="center"><img src="docs/images/themes/accent.gif" width="240" alt="强调色"><br>强调色</td>
    <td align="center"><img src="docs/images/themes/ornate.gif" width="240" alt="花框"><br>花框</td>
  </tr>
  <tr>
    <td align="center"><img src="docs/images/themes/neon.gif" width="240" alt="霓虹"><br>霓虹</td>
    <td align="center"><img src="docs/images/themes/rainbow.gif" width="240" alt="彩虹流光"><br>彩虹流光</td>
    <td align="center"><img src="docs/images/themes/marchingAnts.gif" width="240" alt="跑马灯"><br>跑马灯</td>
  </tr>
  <tr>
    <td align="center"><img src="docs/images/themes/porter.gif" width="240" alt="搬运小人"><br>搬运小人</td>
    <td align="center"><img src="docs/images/themes/lifter.gif" width="240" alt="举重小人"><br>举重小人</td>
    <td align="center"><img src="docs/images/themes/cat.gif" width="240" alt="跳跳猫"><br>跳跳猫</td>
  </tr>
</table>

## 下载安装

需要 macOS 14 及以上，Apple 芯片和 Intel 都支持。

1. 从 [Releases](https://github.com/gabrielsky/mac-tab/releases) 下载最新的 `MacTab-x.y.z.dmg`，打开后把 MacTab 拖进「应用程序」。
2. 第一次打开时，系统会提示无法验证开发者：MacTab 用的是自签名证书，没有经过苹果公证。点「完成」，到「系统设置 → 隐私与安全性」，在页面下方找到 MacTab，点「仍要打开」。
3. 首次启动会弹出授权提示：到「系统设置 → 隐私与安全性 → 辅助功能」里打开 MacTab，立即生效，不用重启。

升级时下载新版覆盖安装即可，不用重新授权。

## 从源码编译

### 一次性准备：创建代码签名证书

辅助功能授权是绑定在签名身份上的。用一个固定的自签名证书签名，重新编译后授权就不会丢。

1. 打开「钥匙串访问」
2. 菜单「钥匙串访问 → 证书助理 → 创建证书…」
3. 名称填 `MacTab Local`，身份类型选「自签名根证书」，证书类型选「代码签名」，勾选「让我覆盖默认值」，点「继续」
4. 有效期填 `3650`（10 年），之后各步保持默认，一路点「继续」直到创建完成

不需要把证书设为「始终信任」。

### 编译与安装

```bash
./scripts/build-app.sh
```

这个脚本会编译 release 版（Apple 芯片和 Intel 通用）并签名，然后安装到 `~/Applications/MacTab.app` 并启动。首次启动同样要按上面第 3 步授权。

## 使用

| 操作 | 效果 |
|---|---|
| Cmd+Tab / Cmd+Shift+Tab | 打开切换器，向后 / 向前选择 |
| 按住 Cmd 时按 ← → | 移动选中项 |
| 松开 Cmd | 切换到选中的应用；它的窗口如果全部最小化，会自动恢复一个 |
| Esc | 取消 |
| Q / H | 退出 / 隐藏选中的应用 |
| 鼠标移动 / 点击 | 选中 / 切换 |

菜单栏图标的菜单里有「设置…」和「退出 MacTab」。设置窗口里可以：

- 选择选中效果主题，右侧实时预览；
- 打开或关闭开机自动启动；
- 查看辅助功能授权状态，未授权时一键打开系统设置。

系统开启「减弱动态效果」时，所有主题都显示为静态。

## 已知限制

- 少数应用（Chrome、微信等）有残留的弹出小窗口，关掉所有窗口后仍可能显示在列表里。
- 切换器里的 Q、H 按物理键位识别，非 QWERTY 布局下对应的是别的键。

## 开发

```bash
swift test
/usr/bin/log show --last 2m --style compact --predicate 'subsystem == "local.mactab"'
```

改了主题后，运行 `./scripts/theme-shots.sh` 重新生成上面的效果图（需要 ffmpeg）。

## 许可证

[MIT](LICENSE)
