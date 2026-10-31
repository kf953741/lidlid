#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEMO_WORK="${LIDLID_DEMO_WORKDIR:-$ROOT/.build/usage-demo}"
mkdir -p "$DEMO_WORK"
swift "$ROOT/scripts/render-usage-demo.swift" "$ROOT" "$DEMO_WORK"

for LOCALE in zh-CN en; do
  ASSET_DIR="$ROOT/docs/assets/$LOCALE"
  INPUTS=()
  DURATIONS=(3.5 3.5 4 3.5 4 3.25)
  for SCENE in {0..5}; do
    INPUTS+=(-loop 1 -framerate 24 -t "${DURATIONS[$((SCENE + 1))]}" -i "$DEMO_WORK/$LOCALE/scene-$SCENE.png")
  done
  ffmpeg -hide_banner -loglevel error -y "${INPUTS[@]}" -filter_complex \
    "[0:v][1:v]xfade=transition=fade:duration=0.35:offset=3.15[a];[a][2:v]xfade=transition=fade:duration=0.35:offset=6.3[b];[b][3:v]xfade=transition=fade:duration=0.35:offset=9.95[c];[c][4:v]xfade=transition=fade:duration=0.35:offset=13.1[d];[d][5:v]xfade=transition=fade:duration=0.35:offset=16.75,format=yuv420p[v]" \
    -map '[v]' -t 20 -r 24 -an -c:v libx264 -preset veryfast -crf 19 -movflags +faststart "$ASSET_DIR/usage-demo.mp4"
  ffmpeg -hide_banner -loglevel error -y -i "$ASSET_DIR/usage-demo.mp4" -filter_complex \
    "fps=8,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    -loop 0 "$ASSET_DIR/usage-demo.gif"
done
print "Created 20-second MP4 and GIF demos in docs/assets/{zh-CN,en}."
