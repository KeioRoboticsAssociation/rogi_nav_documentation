# サンプル起動

sample profile は 2 種類です。シミュレーションでは `sim`、実機では `real` を指定します。

```bash
ros2 launch rogi_nav_sample sample.launch.py config_profile:=sim
```

```bash
ros2 launch rogi_nav_sample sample.launch.py config_profile:=real
```

`sample.launch.py` は内部で `rogi_launch/launch/rogi_nav.launch.py` を呼び出します。
設定は `example/sample/config` 配下から読み込まれます。

設定ディレクトリを差し替える場合だけ、`rogi_nav.launch.py` を直接呼びます。

```bash
ros2 launch rogi_launch rogi_nav.launch.py \
  config_dir:=/home/yuki/rogi_nav_ws/src/rogi_nav/example/sample/config \
  config_profile:=sim
```
