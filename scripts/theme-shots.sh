#!/bin/bash
# 生成 README 的主题效果图：ThemeShotsTests 离线渲染每个主题的动画帧，再用 ffmpeg 合成 GIF
# 用法：scripts/theme-shots.sh；输出 docs/images/themes/<主题>.gif，需要 ffmpeg
set -euo pipefail
cd "$(dirname "$0")/.."

command -v ffmpeg >/dev/null || { echo "错误：需要 ffmpeg（brew install ffmpeg）" >&2; exit 1; }
FRAMES="$(mktemp -d)"
trap 'rm -rf "$FRAMES"' EXIT
OUT="docs/images/themes"

MACTAB_SHOTS_DIR="$FRAMES" swift test --filter ThemeShotsTests
mkdir -p "$OUT"
for dir in "$FRAMES"/*/; do
  name="$(basename "$dir")"
  # 帧率和 ThemeShotsTests.fps 一致；按帧间差异取调色板、只编码变化的区域；有序抖动帧间稳定，GIF 更小
  ffmpeg -loglevel error -y -framerate 20 -i "$dir/%03d.png" \
    -vf "split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
    -loop 0 "$OUT/$name.gif"
done
du -h "$OUT"/*.gif
