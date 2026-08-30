# sick_generic_caller

## 役割

`sick_generic_caller` は SICK picoScan などの LiDAR driver を起動します。rogi_nav 側では scan 生成を実装せず、`sick_scan_xd` を設定ファイルから呼び出します。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| publish | `/lidar*/scan` | `sensor_msgs/msg/LaserScan` |
| publish | `/lidar*/scan_segment` | driver 設定に依存 |
| publish | `/lidar*/imu` | driver 設定に依存 |
| config | `sensing/config.yaml` の `sick_picoscan` | hostname、UDP port、frame、topic |

## 座標条件

各 LiDAR scan 点 {math}`p_i^{L}` は、後段で TF により基準 frame へ変換されます。

```{math}
p_i^{B}=T^{B}_{L}p_i^{L}
```

ここで {math}`L` は LiDAR frame、{math}`B` は `base_link` などの統合先 frame です。`publish_frame_id` が TF tree に無い場合、後段の `scan_merger` はその scan を統合できません。

角度範囲は driver 設定の、

```{math}
\Theta=[\theta_{\min},\theta_{\max}]
```

で制限されます。LiDAR 台数を変えた場合は、driver 側の topic と `scan_merger.scan_topics` を同時に揃えます。

## 設定ファイル

sample では `example/sample/config/sensing/config.yaml` の `sick_picoscan` を使います。

| key | 例 | 用途 |
| --- | --- | --- |
| `sick_picoscan.enabled` | `true` | picoscan 設定全体の有効化 |
| `sick_picoscan.lidars[].nodename` | `picoscan_11` | ROS node 名、default frame 名 |
| `hostname` | `192.168.11.6` | LiDAR 本体 IP |
| `udp_receiver_ip` | `192.168.11.5` | PC 側受信 IP |
| `publish_frame_id` | `picoscan_11` | scan の frame |
| `publish_laserscan_fullframe_topic` | `/lidar1/scan` | 後段へ渡す full scan topic |
| `publish_laserscan_segment_topic` | `/lidar1/scan_segment` | segment scan topic |
| `imu_topic` | `/lidar1/imu` | IMU topic |
| `upside_down` | `false` | true なら driver 引数に 180 deg roll を追加 |
| `angle_range_deg.min/max` | `-138.0`, `138.0` | driver 側の角度 filter |
| `udp_port`, `check_udp_receiver_port`, `imu_udp_port` | `2115`, `2116`, `7503` | UDP port |

`sensing.launch.py` は各 LiDAR 設定を `sick_generic_caller` の launch arguments に変換します。`angle_range_deg` は次の driver 引数へ展開されます。

```text
all_segments_min_deg
all_segments_max_deg
host_set_LFPangleRangeFilter
host_LFPangleRangeFilter
```

profile 側では `launch.components.sensing.picoscan.enabled` が最終的な起動可否です。`localization.method != ransac` の場合、現在の `sensing.launch.py` は sensing 系 action を返しません。
