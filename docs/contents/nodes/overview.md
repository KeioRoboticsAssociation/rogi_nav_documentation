# 全体構成

`rogi_launch/launch/rogi_nav.launch.py` が、profile YAML を読み込んで各 component launch を組み合わせます。
多くの C++ ノードは `rclcpp_components` の composable node として実装され、必要に応じて
`component_container_mt` にロードされます。

`example/sample/config/real.yaml` と `example/sample/config/sim.yaml` の
`launch.components` で、コンポーネント単位またはノード単位に有効/無効を切り替えます。

データの流れは大きく次の順序です。

1. `map_loader` が CSV 地図を `rogi_msgs/msg/Map` として配信し、`map_converter` が自己位置推定用の `OccupancyGrid` に変換します。
2. 実機では `sick_scan_xd` が LiDAR scan を出し、`scan_merger` が複数 scan を `base_link` 基準の 1 本の scan に統合します。シミュレーションでは Gazebo 側の scan が同じ後段に入ります。
3. `line_detector` が scan 点群から RANSAC で線分を抽出し、`emcl2` と `ransac_localizer` が地図、scan、odom、線分を使って `map` 上の robot pose を推定します。
4. `simple_pure_pursuit` が推定 pose と CSV 経路から `/cmd_vel` を生成します。
5. 実機では `cmd_vel_to_dcmotor_node` が `/cmd_vel` を Rogidrive motor command に変換し、`wheel_odometry` が encoder から `/odom` を更新します。
6. `state_node` が BehaviorTree を tick し、`FollowPath` action を通じて pure pursuit の経路実行順を管理します。

frame は `map -> odom -> base_link -> sensor` が基本です。`emcl2` と `ransac_localizer` は `map -> odom` を publish し得るため、同時有効化する場合は profile と TF の競合に注意します。
