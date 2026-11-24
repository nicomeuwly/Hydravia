#!/bin/zsh
# Renders the App Store marketing screenshots (1320 × 2868, sRGB, no alpha)
# from template.html into ../final/<lang>/01.png … 05.png.
# usage: ./render.sh            (both languages)
set -e
here=${0:A:h}
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
tmp=$(mktemp -d)
for lang in fr en; do
  mkdir -p "$here/../final/$lang"
  for n in 1 2 3 4 5; do
    "$chrome" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
      --allow-file-access-from-files --virtual-time-budget=3000 \
      --window-size=1320,2868 --screenshot="$tmp/shot.png" \
      "file://$here/template.html?lang=$lang&n=$n" >/dev/null 2>&1
    # Flatten: through JPEG (best quality) and back, so no alpha channel remains.
    sips -s format jpeg -s formatOptions 100 "$tmp/shot.png" --out "$tmp/shot.jpg" >/dev/null
    sips -s format png "$tmp/shot.jpg" --out "$here/../final/$lang/0$n.png" >/dev/null
    sips -g pixelWidth -g pixelHeight -g hasAlpha "$here/../final/$lang/0$n.png" | tail -3 | tr '\n' ' '
    echo " $lang/0$n.png"
  done
done
