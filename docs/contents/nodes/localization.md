# Localization

自己位置推定系ノードは、wheel odometry、尤度場 MCL、線分 matching による pose 補正を担当します。

| ノード | 実行ファイル / plugin | 説明 |
| --- | --- | --- |
| `emcl2` | `emcl2` / `emcl2::EMcl2Node` | LiDAR と OccupancyGrid を使う particle filter 系の自己位置推定です。 |
| `ransac_localizer` | `rogi_ransac_localizer` / `rogi_ransac_localizer::RansacLocalizer` | 地図の線分と観測線分を対応付けて pose を補正します。 |
| `wheel_odometry` | `wheel_odometry_node` | Rogidrive encoder 情報から omni wheel odometry を計算します。 |
| `pose2d_to_odometry` | `pose2d_to_odometry_node` / `pose2d_to_odometry::Pose2DToOdometryNode` | MCU の `/raw_pose`（IMU+エンコーダ推定、`geometry_msgs/msg/Pose2D`）を `/raw_pose/odom`（`nav_msgs/msg/Odometry`）に変換します。stamp は受信時刻、twist は差分を一次ローパスで平滑化した body 座標系の速度です。`publish_tf: true` で `odom -> base_link` の TF も配信します。real profile では `ransac_localizer` のオドメトリ入力と `simple_pure_pursuit` の `odometry_topic` に使います。 |

いずれも [`components/localization.launch.py`](https://github.com/KeioRoboticsAssociation/rogi_nav/blob/main/rogi_launch/launch/components/localization.launch.py) から起動します。`wheel_odometry` と `pose2d_to_odometry` のパラメータは `localization/<node>/config.yaml`、有効/無効は `launch.components.localization.<node>.enabled` で指定します。

```{toctree}
:maxdepth: 1

localization/emcl2
localization/ransac-localizer
localization/wheel-odometry
```
