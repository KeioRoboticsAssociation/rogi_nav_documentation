# サンプル起動

リポジトリのルートで実行します。各コマンドは ROS ワークスペースをビルドして setup を読み込み、`rogi_launch rogi_nav.launch.py` に example の設定ディレクトリを渡します。

```bash
make sample sim
# 実機
make sample real
```

`make run` は sample の **real** を起動します。シミュレーションには `make run PROFILE=sim` を使います。`make test sim`、`make nhk_2027 sim` でも同様に example を選べます。mode の省略時は real です。

ビルド済み環境で直接起動する場合は、リポジトリのルートで次を実行します。

```bash
source /opt/ros/jazzy/setup.bash
source ../../install/setup.bash
ros2 launch rogi_launch rogi_nav.launch.py \
  config_dir:="$(pwd)/example/sample/config" \
  config_profile:=sim
```

`rogi_nav_sample` パッケージや `sample.launch.py` は現在の構成にはありません。統合 launch の引数は `config_dir`、`config_profile`、`config_file` です。モデル・自己位置推定手法・初期位置は YAML で変更します。

開始待ちの BehaviorTree には、別端末で開始信号を送ります。

```bash
source /opt/ros/jazzy/setup.bash
ros2 topic pub --once /start std_msgs/msg/Bool '{data: true}'
```

Web が有効なら、起動ログに出る `http://<PC IP>:6080/` または QR コードから RViz / Groot Monitor を開けます。標準 sample では sim で有効、real で無効です。

## example ごとの構成

| example | 主な違い |
| --- | --- |
| `sample` | 共通の `control/config.yaml`、`sensing/config.yaml` と `tree/main.xml` を使用。経路 0・1 を収録。 |
| `test` | sensing/control を real・sim で分離。`state/config.yaml` は `tree/odom_only.xml` を選択。開始後 RANSAC 補正を止め、経路 0・1 を開始信号ごとに往復。経路 2 も収録。 |
| `nhk_2027` | 専用 URDF・world、ground / level_1 地図を使用。BT で経路 0〜4、自己位置推定モード、地図、Gazebo 姿勢を切替。 |

`nhk_2027` の BT は `LevelRobot` で Gazebo の姿勢を水平に戻すため、シミュレーション用の動作を含みます。詳細は [](../nodes/state/environment-actions.md) と [](../nodes/simulation.md) を参照してください。

sample の標準 tree は開始待ちなしで走行を始めます。また、経路 2〜11 を要求する記述が残っているため、収録済み経路 0・1 だけを使う場合は tree を合わせてください。test / nhk_2027 は `WaitStart` を使用しています。
