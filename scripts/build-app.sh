#!/bin/bash
# 编译、组装并签名（见 assemble-app.sh）→ 安装到 ~/Applications 并启动
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/assemble-app.sh dev

pkill -u "$UID" -x MacTab || true
# pkill 不等进程退出；旧实例还没退完就 open 会报 -600。最多等约 5 秒
waited=0
while pgrep -u "$UID" -x MacTab >/dev/null; do
  if (( ++waited > 50 )); then
    echo "错误：旧的 MacTab 5 秒内没有退出" >&2
    exit 1
  fi
  sleep 0.1
done
rm -rf ~/Applications/MacTab.app
mkdir -p ~/Applications
cp -R build/MacTab.app ~/Applications/
open ~/Applications/MacTab.app
echo "已安装并启动 ~/Applications/MacTab.app"
