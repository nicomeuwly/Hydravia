#!/bin/zsh
# Renders the App Store header / search artwork from header.html into
# ../final/header/<lang>-<size>.png at 5244 × 2950 and 3840 × 1646 (sRGB,
# no alpha). Drawn at half size with a 2× device scale factor.
# usage: ./render-header.sh
set -e
here=${0:A:h}
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
tmp=$(mktemp -d)
mkdir -p "$here/../final/header"
for lang in fr en; do
  for size in 5244x2950 3840x1646; do
    w=$(( ${size%x*} / 2 )); h=$(( ${size#*x} / 2 ))
    "$chrome" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
      --allow-file-access-from-files --virtual-time-budget=3000 \
      --window-size=$w,$h --screenshot="$tmp/shot.png" \
      "file://$here/header.html?lang=$lang" >/dev/null 2>&1
    # Flatten through JPEG so no alpha channel remains; the store wants PNG.
    sips -s format jpeg -s formatOptions 100 "$tmp/shot.png" --out "$tmp/shot.jpg" >/dev/null
    sips -s format png "$tmp/shot.jpg" --out "$here/../final/header/$lang-$size.png" >/dev/null
    sips -g pixelWidth -g pixelHeight -g hasAlpha "$here/../final/header/$lang-$size.png" | tail -3 | tr '\n' ' '
    echo " $lang-$size.png"
  done
done
