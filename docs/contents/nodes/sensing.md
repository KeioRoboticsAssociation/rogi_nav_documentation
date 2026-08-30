# Sensing

センシング系ノードは、LiDAR driver、複数 scan の統合、scan 点群からの幾何特徴抽出を担当します。

| ノード | 実行ファイル / plugin | 説明 |
| --- | --- | --- |
| `sick_generic_caller` | `sick_scan_xd` | SICK picoScan などの LiDAR driver を起動します。 |
| `scan_merger` | `rogi_lidar_merger` / `rogi_lidar_merger::ScanMerger` | 複数 LiDAR の `LaserScan` を共通 frame に統合します。 |
| `line_detector` | `rogi_ransac` / `line_detector::line_detector` | `LaserScan` から RANSAC で直線、線分、角を検出します。 |

```{toctree}
:maxdepth: 1

sensing/sick-generic-caller
sensing/scan-merger
sensing/line-detector
```
