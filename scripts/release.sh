#!/bin/bash
# 打包发布用的 DMG：签名好的 MacTab.app 加一个「应用程序」快捷方式，方便拖拽安装；DMG 本身也签名
# 用法：scripts/release.sh <版本号>，如 1.0.0；输出 build/MacTab-<版本号>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?用法：$0 <版本号>（如 1.0.0）}"
DMG="build/MacTab-$VERSION.dmg"
STAGE="build/dmg"

# 发布版必须用固定证书签名，用户升级后授权才不会失效
if ! security find-identity -p codesigning | grep -q '"MacTab Local"'; then
  echo "错误：发布需要证书「MacTab Local」，先运行 scripts/setup-cert.sh" >&2
  exit 1
fi
scripts/assemble-app.sh "$VERSION"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
ditto build/MacTab.app "$STAGE/MacTab.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "MacTab $VERSION" -srcfolder "$STAGE" -format UDZO -quiet "$DMG"
codesign --force --sign "MacTab Local" "$DMG"
rm -rf "$STAGE"
echo "已生成 $DMG"
