# Gazebo シミュレーション

ディレクトリ名は `rogi_simulator`、ROS パッケージ名は `gazebo_simulator` です。統合起動は `make <example> sim`、単体起動は次を使います。

```bash
ros2 launch gazebo_simulator simple_sim.launch.py
```

## ロボットと world

`simple_sim.launch.py` は `model` に `four_wheel_omni`、`three_wheel_omni`、`simple_rover` を受け付けます。`robot_xacro` を指定した場合はそのファイルを優先します。Gazebo にスポーンする entity 名は `robot` です。統合 launch では `example/<example>/urdf/omni_robot.urdf.xacro` があれば自動選択します。

統合 launch の設定例です。

```yaml
simulation:
  use_sim_time: true
  model: four_wheel_omni
  use_simple_world: false
  world_path: ../field/nhk_2027.sdf
  spawn_z: 0.11
  headless: false
  enable_odom_drift: true
```

`use_simple_world=true` は標準 world を使います。false で `world_path` があればその SDF、指定がなければ地図 CSV から生成します。統合 launch は独自 world 指定時に CSV 引数を空にします。単体 launch に world と CSV を両方渡した場合は CSV 生成が優先です。spawn の x・y・yaw は `initial_pose.yaml` から、z は `simulation.spawn_z`（既定 `0.05`）から取得します。

## 地図 CSV からの壁生成

`map_world_generator.py` は連続した線分の閉ループ、向き、入れ子を検出します。最外周をフィールド境界、その内側を障害物として、壁中心を厚さの半分だけずらし、走行空間から観測する壁面を地図線に合わせます。入れ子では境界・障害物の役割を交互に切り替えます。CSV の線分が連続して閉じるように並べてください。

`map.wall_height` と `map.wall_thickness` で高さと厚さを設定します。独自 SDF world はこの生成処理を通らないため、地図と SDF の形状をそれぞれ合わせます。

## センサ・odometry

| ノード / 機能 | 主な入出力 |
| --- | --- |
| `ros_gz_bridge` | `/cmd_vel` を Gazebo へ、`/clock`・`/odom_raw`・scan・IMU・カメラなどを ROS へ |
| `odom_drift_simulator.py` | `/odom_raw` → `/odom`。倍率、距離当たりの偏り、ノイズを付与 |
| `odom_tf_broadcaster.py` | `/odom` → TF `odom → base_link`。真値・推定誤差も表示 |
| `scan_frame_normalizer.py` | `/scan` → `/scan_for_localization`。LaserScan の frame を設定 |
| `pose_comparison_gui.py` | 真値 `/odom_raw` と `/localization_pose` の x・y・yaw を時系列表示 |

補助ノードの ROS パラメータは `simulation/config.yaml` の各 `ros__parameters` で指定します。`enable_odom_drift=false` ではドリフトを無効化します。純粋な追従誤差を確認する場合と自己位置推定の補正を確認する場合で設定を使い分けられます。

## nhk_2027

専用 world は `example/nhk_2027/field/nhk_2027.sdf`、地図は `config/map/ground` と `config/map/level_1` です。world だけを確認する場合はリポジトリのルートで実行します。

```bash
source /opt/ros/jazzy/setup.bash
ros2 launch ./example/nhk_2027/field/field.launch.py
```

BT は地上から level_1 への経路と地図切替を含みます。[](state/environment-actions.md) の `LevelRobot` による姿勢の直接変更を含むため、実機で同じ動作を行うには実機用 tree を用意します。
