# Docker でのセットアップ

リポジトリのルートで、ローカルビルドまたは配布イメージの取得を行います。

```bash
make build
# 配布イメージを使う場合
make pull
```

イメージは依存環境を提供し、ソースはリポジトリ全体を `/ros2_ws/src/rogi_nav` に bind mount します。外部ツールの取得には GitHub の SSH 認証が必要です。`make shell` はホストの SSH agent、`~/.ssh`、`~/.gitconfig` をコンテナへ渡します。

```bash
make shell
# コンテナ内で実行
make setup
```

取得した `common_tool` の外部ツールはホストにも残ります。シミュレーションはホストのグラフィカルセッションから次で起動します。

```bash
ROGI_NAV_IMAGE=ghcr.io/keioroboticsassociation/rogi_nav:jazzy \
  docker/run_sim.sh
```

このスクリプトは X11、GPU、ワークスペースを設定し、ビルドして sample の sim を起動します。NVIDIA が利用できない場合は DRI またはソフトウェア描画を使用します。

```bash
ROGI_NAV_IMAGE=ghcr.io/keioroboticsassociation/rogi_nav:jazzy \
ROGI_NAV_CONFIG_DIR=/ros2_ws/src/rogi_nav/example/test/config \
ROGI_NAV_CONFIG_PROFILE=sim \
  docker/run_sim.sh
```

`make run` は Docker 起動用ではなく、ホスト上で sample の real を起動するコマンドです。停止は起動端末の `Ctrl+C` で行います。現在の Makefile には `down` の実行処理がないため、`make down` は停止操作として使えません。
