# サンプル起動

実機向けの sample profile は `real`、シミュレーション向けは `sim` です。

```bash
ros2 launch rogi_nav_sample sample.launch.py config_profile:=real
```

```bash
ros2 launch rogi_nav_sample sample.launch.py config_profile:=sim
```

`sample.launch.py` は内部で `rogi_launch/launch/rogi_nav.launch.py` を呼び出します。
設定は `example/sample/config` 配下から読み込まれます。

直接 `rogi_nav.launch.py` を使う場合は、設定ディレクトリと profile を指定します。

```bash
ros2 launch rogi_launch rogi_nav.launch.py \
  config_dir:=/home/yuki/rogi_nav_ws/src/rogi_nav/example/sample/config \
  config_profile:=sim
```
