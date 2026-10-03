#!/bin/bash
# 编译通用二进制（Apple 芯片 + Intel）→ 组装 build/MacTab.app → 用固定证书签名
# 用法：scripts/assemble-app.sh <版本号>
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?用法：$0 <版本号>}"
IDENTITY="MacTab Local"
APP="build/MacTab.app"

if ! security find-identity -p codesigning | grep -q "$IDENTITY"; then
  echo "错误：钥匙串里找不到代码签名证书「$IDENTITY」，创建步骤见 README.md" >&2
  exit 1
fi

ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/MacTab"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/MacTab"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>local.mactab</string>
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
codesign --force --sign "$IDENTITY" "$APP"
