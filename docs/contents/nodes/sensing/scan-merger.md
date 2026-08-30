# scan_merger

## 役割

`scan_merger` は複数の `LaserScan` を 1 本の仮想 scan に再投影します。入力は各 LiDAR frame、出力は `frame_id` parameter、通常 `base_link` です。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| subscribe | `scan_topics` | `sensor_msgs/msg/LaserScan` の配列 |
| publish | `merged_scan` remap 後 `/scan_for_localization` | `sensor_msgs/msg/LaserScan` |
| parameter | `frame_id` | 出力 frame |
| parameter | `frequency` | publish 周期 |
| parameter | `angle_min`, `angle_max`, `angle_increment` | 出力 scan の角度 grid |
| parameter | `range_min`, `range_max` | 出力 scan の距離範囲 |

## 出力 bin

出力 bin 数は次式です。

```{math}
N=\left\lfloor\frac{\theta_{\max}-\theta_{\min}}{\Delta\theta}\right\rfloor+1
```

初期 range は全 bin で {math}`+\infty` です。

```{math}
r_k=+\infty,\qquad k=0,\dots,N-1
```

## 入力 beam の再投影

入力 beam index {math}`i` の角度は、

```{math}
\theta_i^S=\theta_{\min}^S+i\Delta\theta^S
```

です。有効 range {math}`\rho_i` を入力 frame の点へ変換します。

```{math}
p_i^S=
\begin{bmatrix}
\rho_i\cos\theta_i^S\\
\rho_i\sin\theta_i^S\\
0
\end{bmatrix}
```

TF で出力 frame へ変換します。

```{math}
p_i^O=T^O_S p_i^S
```

出力 frame で極座標に戻します。

```{math}
\rho_i^O=\sqrt{(x_i^O)^2+(y_i^O)^2},\qquad
\theta_i^O=\operatorname{atan2}(y_i^O,x_i^O)
```

出力範囲に入る場合、bin index は丸めで決めます。

```{math}
k=\operatorname{round}\left(\frac{\theta_i^O-\theta_{\min}}{\Delta\theta}\right)
```

同じ bin では最小距離を採用します。

```{math}
r_k\leftarrow\min(r_k,\rho_i^O)
```

この最小化により、複数 LiDAR が同じ方向を見た場合も LaserScan として自然な「最初の hit」を残します。

## 時刻ずれ

厳密な同期は行いません。topic ごとの最新 scan を timer 周期で統合します。ロボット速度を {math}`v`、scan 間の時刻ずれを {math}`\Delta t` とすると、並進方向の見かけ誤差は概ね {math}`v\Delta t` です。

## 設定ファイル

sample では `example/sample/config/sensing/config.yaml` の `scan_merger.ros__parameters` と `sick_picoscan` の両方が関係します。

| 設定元 | key | 対応 |
| --- | --- | --- |
| `sensing/config.yaml` | `scan_merger.ros__parameters.scan_topics` | picoscan 無効時の入力 scan topic 配列 |
| `sensing/config.yaml` | `sick_picoscan.lidars[].publish_laserscan_fullframe_topic` | picoscan 有効時の入力 scan topic 配列 |
| `localization/config.yaml` | `topics.localization_scan` | `merged_scan` の remap 先 |
| `real.yaml` / `sim.yaml` | `launch.components.sensing.scan_merger.enabled` | ノード起動の有効/無効 |

picoscan が有効な場合、`scan_topics` は YAML の `scan_merger` ではなく LiDAR 定義から自動生成されます。

```{math}
S=[\mathrm{lidars}[i].\mathrm{publish\_laserscan\_fullframe\_topic}]
```

picoscan が無効な場合は `scan_merger.ros__parameters.scan_topics` を使います。sample では次です。

```yaml
scan_merger:
  ros__parameters:
    scan_topics:
      - /lidar1/scan
      - /lidar2/scan
```

`frame_id` と `frequency` は YAML ではなく `sensing.launch.py` の launch argument です。default は `base_link` と `40.0` Hz です。`angle_min/max`、`angle_increment`、`range_min/max`、`scan_time` は launch から渡されないため、実装 default が使われます。
