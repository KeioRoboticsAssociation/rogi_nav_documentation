# Localization

| ノード | 実行ファイル / plugin | 説明 |
| --- | --- | --- |
| `emcl2` | `emcl2` / `emcl2::EMcl2Node` | LiDAR と OccupancyGrid を使う particle filter 系の自己位置推定です。 |
| `ransac_localizer` | `rogi_ransac_localizer` / `rogi_ransac_localizer::RansacLocalizer` | 地図の線分と観測線分を対応付けて pose を補正します。 |
| `wheel_odometry` | `wheel_odometry_node` | Rogidrive encoder 情報から omni wheel odometry を計算します。 |

| ノード | 種別 | 名前 | 型 / 内容 |
| --- | --- | --- | --- |
| `emcl2` | subscribe | `scan`, `map`, `initialpose` | `LaserScan`, `OccupancyGrid`, `PoseWithCovarianceStamped` |
| `emcl2` | publish | `localization_pose`, `particlecloud`, `alpha` | 推定 pose、particle、信頼度 |
| `emcl2` | service | `global_localization` | `std_srvs/srv/Empty` |
| `ransac_localizer` | subscribe | `map`, `odom`, `line_segments` | 地図、odometry、観測線分 |
| `ransac_localizer` | publish | `localization_pose` | `geometry_msgs/msg/PoseWithCovarianceStamped` |
| `wheel_odometry` | subscribe | `/rogidrive_status` | Rogidrive status |
| `wheel_odometry` | publish | `/odom` | `nav_msgs/msg/Odometry` |
| `wheel_odometry` | tf | `odom` -> `base_link` | `publish_tf` が true の場合に publish |
