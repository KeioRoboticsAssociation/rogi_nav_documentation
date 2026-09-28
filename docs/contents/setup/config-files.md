# 主要な設定ファイル

`D = example/<example>/config` を設定の基準ディレクトリとします。

| ファイル | 役割 |
| --- | --- |
| `D/real.yaml`, `D/sim.yaml` | `launch.components` による起動可否、sim time、各セクションの上書き |
| `D/initial_pose.yaml` | 共通初期位置 `initial_pose.x/y` [m]、`yaw` [degree] |
| `D/simulation/config.yaml` | Gazebo model、world、spawn 高さ、odom drift |
| `D/map/config.yaml` | 地図 CSV、壁生成、map_loader / map_converter のパラメータ |
| `D/sensing/config.yaml` または `D/sensing/<profile>/config.yaml` | LiDAR、scan merger、line detector |
| `D/localization/config.yaml` | `localization.method`（`ransac` / `emcl2`）、入出力 topic |
| `D/localization/{emcl2,ransac}/config.yaml` | 自己位置推定の ROS パラメータ |
| `D/localization/wheel_odometry/config.yaml` | エンコーダ、車輪配置、減速比、TF |
| `D/control/config.yaml` または `D/control/<profile>/config.yaml` | pure pursuit、停止制御、モータ変換 |
| `D/state/config.yaml` | `state_node.ros__parameters.tree_path`、`move_index` |
| `D/tree/*.xml` | BehaviorTree。本体は `tree_path` で選ぶ |
| `D/path/trajectory/{0..11}.csv` | 追従・表示用の `x,y,theta` [m,m,rad]。存在する経路だけ実行可能 |
| `D/path/wayoints/*.csv` | 経路生成用の編集データ。ディレクトリ名の綴りは現状のまま |
| `D/visualization/config.yaml` | RViz 設定、可視化パラメータ |
| `D/mavlink_ros2/rs485_interface2_motor_mapping.yaml` | 実機インターフェースのモータ対応 |

## 読み込み順

1. `simulation` → `localization` → `sensing` → `map` → `control` → `state` → `visualization` の順にセクションを読み込みます。
2. 短い profile 名（`real` / `sim` など）なら、存在する `<section>/<profile>/config.yaml` を `<section>/config.yaml` の代わりに選びます。共通ファイルへの部分追加ではないため、必要な設定を揃えてください。共通ファイルにフォールバックした場合は旧形式 `<section>/<profile>.yaml` もマージします。
3. `config_file` があればそのファイルを、なければ `<config_profile>.yaml`（省略時 `real.yaml`）を再帰マージします。`config_file` の相対パスは `config_dir` 基準です。セクションファイルの選択には引き続き `config_profile` を使います。
4. 最後に `initial_pose.yaml` をマージし、自己位置推定・wheel odometry・Gazebo spawn に適用します。`yaw` は launch 内で rad に変換されます。

ノード別の補助 YAML を直接渡す箇所もあります。モータ変換は選択した control YAML を直接読みます。pure pursuit の `launch.components.pure_pursuit.simple_pure_pursuit.parameters` は、ROS パラメータの最上位キー単位で上書きします。ネストした `path` を部分指定すると基本設定の `path` 全体を置き換えます。

地図 CSV は `D/map`、tree と `simulation.world_path` は `D` を基準に解決します。絶対パスも使用できます。`example/<example>/urdf/omni_robot.urdf.xacro` があれば、その example のロボットモデルとして渡します。

## BehaviorTree の選択

```yaml
state_node:
  ros__parameters:
    tree_path: tree/odom_only.xml
    move_index: 0
```

この例は test の設定です。`odom_only` は RANSAC localizer の補正停止モードで、`localization.method` の値ではありません。現在の launch が起動する自己位置推定は `ransac` または `emcl2` です。
