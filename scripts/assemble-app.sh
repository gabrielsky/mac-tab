#!/bin/bash
# 编译通用二进制（Apple 芯片 + Intel）→ 组装 build/MacTab.app → 用固定证书签名，没有证书时用临时签名
# 用法：scripts/assemble-app.sh <版本号>
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?用法：$0 <版本号>}"
IDENTITY="MacTab Local"
APP="build/MacTab.app"

# 临时签名每次编译都不一样，系统会当成新应用，辅助功能授权随之失效
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
  SIGN="$IDENTITY"
else
  SIGN="-"
  echo "提示：没有证书「$IDENTITY」，改用临时签名。每次重新编译后都要重新授权辅助功能" >&2
  echo "      （先运行 tccutil reset Accessibility local.mactab）。运行 scripts/setup-cert.sh 创建一次证书就不用了。" >&2
fi

ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/MacTab"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacTab"
cp -R Resources/*.lproj "$APP/Contents/Resources/" # 界面翻译，按系统语言选用
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>local.mactab</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleName</key><string>MacTab</string>
  <key>CFBundleExecutable</key><string>MacTab</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign "$SIGN" "$APP"
