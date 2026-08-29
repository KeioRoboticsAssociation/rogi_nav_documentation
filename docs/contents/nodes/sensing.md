# Sensing

| ノード | 実行ファイル / plugin | 説明 |
| --- | --- | --- |
| `sick_generic_caller` | `sick_scan_xd` | SICK picoScan などの LiDAR driver を起動します。設定は `sensing/config.yaml` の `sick_picoscan` で行います。 |
| `scan_merger` | `rogi_lidar_merger` / `rogi_lidar_merger::ScanMerger` | 複数 LiDAR の `LaserScan` を共通 frame に統合します。 |
| `line_detector` | `rogi_ransac` / `line_detector::line_detector` | `LaserScan` から RANSAC で直線、線分、角を検出します。 |

| ノード | 種別 | 名前 | 型 / 内容 |
| --- | --- | --- | --- |
| `scan_merger` | subscribe | `scan_topics` | `sensor_msgs/msg/LaserScan` の配列 |
| `scan_merger` | publish | `merged_scan` remap 後 `/scan_for_localization` | `sensor_msgs/msg/LaserScan` |
| `scan_merger` | parameter | `frame_id`, `frequency`, `angle_*`, `range_*` | 出力 scan の frame と範囲 |
| `line_detector` | subscribe | `scan` | `sensor_msgs/msg/LaserScan` |
| `line_detector` | publish | `lines`, `line_segments`, `corners` | `rogi_msgs` と `PoseArray` |
| `line_detector` | parameter | `max_iterations`, `max_lines`, `distance_threshold` など | RANSAC 検出条件 |
