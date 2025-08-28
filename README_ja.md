# Quilt タイルモザイクスクリプト

フォルダ内の画像を指定した行数と列数で並べ、一枚のタイルモザイク画像として出力するシンプルな Bash ツール。

## 概要
指定したフォルダ内の画像ファイルをグリッド状に並べて一枚の画像を出力する。フォルダ内の画像枚数が行数×列数と一致しない場合はエラーで停止する。

## 動作要件
* ImageMagick v7 を推奨。可能なら `magick` コマンドを使う
* 自然順ソートのために Python 3 が必要
* macOS の既定 Bash（古いバージョン）でも動作するよう互換性を持たせている

## インストール
macOS（Homebrew を使用する場合）
```bash
brew install imagemagick python
```

Ubuntu / Debian
```bash
sudo apt update
sudo apt install imagemagick python3
```

## 使い方
基本構文
```bash
bash Quilt.sh PATH_TO_IMAGES ROWS COLS OUTPUT_FILE
```

例
```bash
bash Quilt.sh ./imgs 2 5 out.png
```

並べ順の指定（環境変数）
* `TILE_SORT` に `natural` または `mtime` または `random` を設定するとファイルの並び順を制御できる
* `TILE_REVERSE` に `1` を設定すると並びを逆にする

例
```bash
# ファイル名の自然順
TILE_SORT=natural bash Quilt.sh ./imgs 2 5 out.png

# 更新時刻順
TILE_SORT=mtime bash Quilt.sh ./imgs 2 5 out.png

# ランダム順で逆順
TILE_SORT=random TILE_REVERSE=1 bash Quilt.sh ./imgs 2 5 out.png
```

## 対応拡張子
`tif`, `tiff`, `png`, `jpg`, `jpeg`, `bmp`, `webp` など一般的な画像形式を扱う

## 動作の挙動
* 隠し macOS メタファイルは自動で無視する
* 画像サイズが異なる場合でも各セル内でアスペクト比を保持して配置する
* 行数×列数と画像枚数が一致しない場合はエラーで停止する

## テスト画像を作る
ImageMagick でテスト画像を作る例
```bash
mkdir -p imgs
for i in $(seq 1 10); do
  magick -size 160x120 xc:white -gravity center -pointsize 28 -annotate 0 "$i" "imgs/$i.png"
done
```

## トラブルシュート
* `convert` の非推奨警告が出る場合は `magick` を使う
* 画像枚数の不一致エラーが出たら `.DS_Store` や `._...` のようなメタファイルが混ざっていないか確認する
* Python 3 が見つからない場合は Python 3 をインストールするか、Python 3 が使える環境で実行する

## 継続的インテグレーション
GitHub Actions 用の簡単なワークフローを用意している。CI はテスト画像を作成し、スクリプトを実行して出力ファイルの存在を確認する

## ライセンス
BSD 3-Clause License
Copyright (c) 2025, koh-nakagawa

