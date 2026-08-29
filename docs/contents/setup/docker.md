# Docker でのセットアップ

Docker image をローカルでビルドします。

```bash
cd ~/rogi_nav_ws/src/rogi_nav
make build
```

GitHub Container Registry の image を使う場合は次を実行します。

```bash
make pull
```

コンテナ内でシェルを開き、外部ツールをセットアップします。

```bash
ssh -T git@github.com
make shell
make setup
```

シミュレーションを起動します。

```bash
make run
```

launch 引数を渡す場合は `LAUNCH_ARGS` を使います。

```bash
make run LAUNCH_ARGS="config_profile:=sim"
```
