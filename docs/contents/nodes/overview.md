# 全体構成

`rogi_launch/launch/rogi_nav.launch.py` が、profile YAML を読み込んで各 component launch を組み合わせます。
多くの C++ ノードは `rclcpp_components` の composable node として実装され、必要に応じて
`component_container_mt` にロードされます。

`example/sample/config/real.yaml` と `example/sample/config/sim.yaml` の
`launch.components` で、コンポーネント単位またはノード単位に有効/無効を切り替えます。

ノードはパッケージのディレクトリごとに 1 つの component launch から起動します。`launch.components` の key も同じ対応です。
各パッケージには launch / config を同梱せず、パラメータは `example/<example>/config/<component>/` に置きます。

`rogi_nav.launch.py` は launch をまとめるだけで、ノードを直接起動しません。各 component launch に
`config_dir` / `config_profile` / `config_file` だけを渡して include します。録画用の引数
（`record_all` / `record_output_dir` / `record_bag_name` / `record_storage_id`）は `rosbag_record_all.launch.py` が宣言し、
`record_all:=true` のときは録画を先に開始して `component_start_delay` を 1 秒に設定します。`rogi_nav.launch.py` はその値だけ component の起動を遅らせます。
各 component の include は `GroupAction(scoped=True)` で囲み、component 内（例: `simple_sim.launch.py` の `config_file`）で設定された
launch configuration が後続の component に漏れないようにしています（ROS 2 の `IncludeLaunchDescription` 自体はスコープを持ちません）。
設定の読込と有効/無効の判定は各 component launch が共通モジュール `components/component_config.py` を使って行うため、
component 単体でも同じ設定で起動できます。

```bash
ros2 launch rogi_launch control.launch.py config_dir:=$PWD/example/haru_revenge/config config_profile:=real
```

| ディレクトリ | component launch | `launch.components` | ノード |
| --- | --- | --- | --- |
| `rogi_control` | `components/control.launch.py` | `control` | `simple_pure_pursuit`, `cmd_vel_to_dcmotor` |
| `rogi_localization` | `components/localization.launch.py` | `localization` | `ransac_localizer`, `emcl2`, `wheel_odometry`, `pose2d_to_odometry` |
| `rogi_map` | `components/map.launch.py` | `map` | `map_loader`, `map_converter` |
| `rogi_sensing` | `components/sensing.launch.py` | `sensing` | `scan_merger`, `line_detector`（PicoScan ドライバも同 launch） |
| `rogi_state` | `components/state.launch.py` | `state` | `state_node`（Groot も同 launch） |
| `rogi_visualization` | `components/visualization.launch.py` | `visualization` | `line_segments_visualizer`, `path_visualizer`, `rviz2` |
| `rogi_simulator` | `components/gazebo.launch.py` | `gazebo` | `simple_sim`（Gazebo 一式）, `pose_comparison_gui` |
| `common_tool/web` | `components/web.launch.py` | `web` | `rogi_web` |
| `common_tool/MAVLink_ros2` | `components/mavlink.launch.py` | `mavlink` | `stm32_full`, `rs485_interface2` |
| （外部パッケージ） | `components/tf.launch.py` | `tf` | `robot_state_publisher`（real profile かつ URDF がある場合。sim は Gazebo 側が配信） |

旧配置の key（`launch.components.pure_pursuit.simple_pure_pursuit`、`launch.components.control.simple_sim`、`launch.components.control.pose2d_to_odometry`）も、
録画時に保存された設定を再利用できるよう引き続き読み込みます。

データの流れは大きく次の順序です。

1. `map_loader` が CSV 地図を `rogi_msgs/msg/Map` として配信し、`map_converter` が自己位置推定用の `OccupancyGrid` に変換します。
2. 実機では `sick_scan_xd` が LiDAR scan を出し、`scan_merger` が複数 scan を `base_link` 基準の 1 本の scan に統合します。シミュレーションでは Gazebo 側の scan が同じ後段に入ります。
3. `line_detector` が scan 点群から RANSAC で線分を抽出し、選択した `ransac_localizer` が地図線分・観測線分・odom、または `emcl2` が占有格子・scan・odom TF を使って `map` 上の robot pose を推定します。
4. `simple_pure_pursuit` が推定 pose と CSV 経路から `/cmd_vel` を生成します。
5. 実機では `cmd_vel_to_dcmotor_node` が `/cmd_vel` を Rogidrive motor command に変換し、`wheel_odometry` が encoder から `/odom` を更新します。
6. `state_node` が BehaviorTree を tick し、`FollowPath` action を通じて pure pursuit の経路実行順を管理します。

frame は `map -> odom -> base_link -> sensor` が基本です。統合 launch は `localization.method` に一致し、かつ enabled の自己位置推定ノードを起動します。両方の enabled が true でも手法は一方が選ばれます。
