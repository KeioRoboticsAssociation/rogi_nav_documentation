# Localization

自己位置推定系ノードは、wheel odometry、尤度場 MCL、線分 matching による pose 補正を担当します。

| ノード | 実行ファイル / plugin | 説明 |
| --- | --- | --- |
| `emcl2` | `emcl2` / `emcl2::EMcl2Node` | LiDAR と OccupancyGrid を使う particle filter 系の自己位置推定です。 |
| `ransac_localizer` | `rogi_ransac_localizer` / `rogi_ransac_localizer::RansacLocalizer` | 地図の線分と観測線分を対応付けて pose を補正します。 |
| `wheel_odometry` | `wheel_odometry_node` | Rogidrive encoder 情報から omni wheel odometry を計算します。 |

```{toctree}
:maxdepth: 1

localization/emcl2
localization/ransac-localizer
localization/wheel-odometry
```
