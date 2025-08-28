#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "使い方: $0 DIR ROWS COLS [OUT]"
  echo "例: $0 ./imgs 2 5 mosaic.png"
  exit 1
}

if [ $# -lt 3 ]; then usage; fi

DIR="$1"
ROWS="$2"
COLS="$3"
OUT="${4:-mosaic.png}"

# GNU sort -V が必要。macOSはgsortで代替
if sort -V </dev/null >/dev/null 2>&1; then
  SORT_BIN="sort"
elif command -v gsort >/dev/null 2>&1; then
  SORT_BIN="gsort"
else
  echo "[ERROR] GNU sort -V が見つからない。coreutilsを導入してください" >&2
  exit 1
fi

mapfile -t FILES < <(find "$DIR" -maxdepth 1 -type f \
  \( -iname "*.tif" -o -iname "*.tiff" -o -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.bmp" -o -iname "*.webp" \) \
  -printf "%f\n" | $SORT_BIN -V)

COUNT="${#FILES[@]}"
EXPECTED=$((ROWS * COLS))
if [ "$COUNT" -ne "$EXPECTED" ]; then
  echo "[ERROR] 画像枚数 $COUNT が rows×cols=$EXPECTED と一致しない" >&2
  exit 1
fi

# ベース名でソートしたのでフルパスに戻す
for i in "${!FILES[@]}"; do
  FILES[$i]="$DIR/${FILES[$i]}"
done

# 隙間や背景などは必要に応じて調整
montage -tile "${COLS}x${ROWS}" -geometry +0+0 -background white "${FILES[@]}" "$OUT"
echo "[OK] 出力: $OUT"

