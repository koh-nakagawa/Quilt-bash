#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "使い方: $0 DIR ROWS COLS [OUT]"
  echo "例: $0 ./imgs 2 5 mosaic.png"
  echo
  echo "環境変数:"
  echo "  TILE_SORT=natural|mtime|random   既定 natural"
  echo "  TILE_REVERSE=1                   逆順にする"
  exit 1
}

[ $# -lt 3 ] && usage

DIR="$1"
ROWS="$2"
COLS="$3"
OUT="${4:-mosaic.png}"

if [ ! -d "$DIR" ]; then
  echo "[ERROR] フォルダが存在しない: $DIR" >&2
  exit 1
fi

# ImageMagick v7 対応: magick があれば優先
if command -v magick >/dev/null 2>&1; then
  MONTAGE=(magick montage)
  IDENTIFY=(magick identify)
else
  if ! command -v montage >/dev/null 2>&1; then
    echo "[ERROR] ImageMagick が見つからない。magick または montage を導入してほしい" >&2
    exit 1
  fi
  MONTAGE=(montage)
  IDENTIFY=(identify)
fi

# 対象拡張子を glob で収集（非再帰）
shopt -s nullglob nocaseglob
raw_files=()
for ext in tif tiff png jpg jpeg bmp webp; do
  for f in "$DIR"/*."$ext"; do
    [ -f "$f" ] && raw_files+=("$f")
  done
done
shopt -u nocaseglob

if [ "${#raw_files[@]}" -eq 0 ]; then
  echo "[ERROR] 対象拡張子の画像が見つからない" >&2
  exit 1
fi

# フィルタ: macOS メタファイルを除外しつつ順序を保って重複除去
filtered_tmp=$(mktemp)
removed_count=0
for f in "${raw_files[@]}"; do
  bn=$(basename "$f")
  case "$bn" in
    .DS_Store|Thumbs.db|._*) 
      removed_count=$((removed_count+1))
      continue
      ;;
  esac
  if ! grep -Fxq "$f" "$filtered_tmp" 2>/dev/null; then
    printf '%s\n' "$f" >> "$filtered_tmp"
  fi
done

# mapfile を使わない読み込み（Bash 3 互換）
files=()
while IFS= read -r line; do
  files+=("$line")
done < "$filtered_tmp"
rm -f "$filtered_tmp"

if [ "${#files[@]}" -eq 0 ]; then
  echo "[ERROR] フィルタリング後に画像が残らない" >&2
  exit 1
fi

# 並べ順の指定
SORT_MODE="${TILE_SORT:-natural}"    # natural mtime random
REVERSE="${TILE_REVERSE:-0}"         # 1 で逆順

if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERROR] 並べ替えに python3 が必要。Conda か Homebrew で用意してほしい" >&2
  exit 1
fi

# Python 側で NUL 区切りで並べ替えて返す
# 注意: Python 側で末尾の NUL を付けないようにする（join を使う）
sorted_files=()
while IFS= read -r -d '' f; do
  # 空文字が来たら無視（安全策）
  [ -z "$f" ] && continue
  sorted_files+=("$f")
done < <(
  python3 - "$SORT_MODE" "$REVERSE" -- "${files[@]}" <<'PY'
import sys, os, re, random
mode = sys.argv[1]
reverse = sys.argv[2] == '1'
files = sys.argv[3:]

def natural_key(p):
    b = os.path.basename(p)
    parts = re.split(r'(\d+)', b)
    return [int(x) if x.isdigit() else x.lower() for x in parts]

if mode in ('natural', 'name'):
    files.sort(key=natural_key, reverse=reverse)
elif mode == 'mtime':
    files.sort(key=lambda p: os.path.getmtime(p), reverse=reverse)
elif mode == 'random':
    random.shuffle(files)
    if reverse:
        files.reverse()
else:
    files.sort(reverse=reverse)

# join で区切りを入れるが末尾に余分な区切りを付けない
out = b'\0'.join([f.encode('utf-8') for f in files])
sys.stdout.buffer.write(out)
PY
)

files=("${sorted_files[@]}")

# デバッグ出力: 実際に使うファイルを表示
echo "matched count=${#files[@]} (removed metadata/dupes earlier)"
i=1
for f in "${files[@]}"; do
  echo "  $(printf '%2d' "$i"): $(basename "$f")"
  i=$((i+1))
done

COUNT="${#files[@]}"
EXPECTED=$((ROWS * COLS))
if [ "$COUNT" -ne "$EXPECTED" ]; then
  echo "[ERROR] 画像枚数 $COUNT が rows×cols=$EXPECTED と一致しない" >&2
  exit 1
fi

# 合成 実サイズは入力依存。隙間なし 背景白
"${MONTAGE[@]}" -tile "${COLS}x${ROWS}" -geometry +0+0 -background white "${files[@]}" "$OUT"
echo "[OK] 出力: $OUT"

# 参考情報: identify が使えるなら表示
if command -v "${IDENTIFY[0]}" >/dev/null 2>&1; then
  "${IDENTIFY[@]}" "$OUT" || true
fi
