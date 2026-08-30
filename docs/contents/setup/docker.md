# Docker でのセットアップ

ローカルで image を作る場合は次を実行します。

```bash
cd ~/rogi_nav_ws/src/rogi_nav
make build
```

配布済み image を使う場合は `make pull` だけで構いません。

```bash
make pull
```

シミュレーションは次で起動します。

```bash
make run
```

profile を明示する場合は `LAUNCH_ARGS` に渡します。

```bash
make run LAUNCH_ARGS="config_profile:=sim"
```

コンテナ内で手作業する場合だけ、シェルを開いてから通常のホスト手順を実行します。

```bash
make shell
```
