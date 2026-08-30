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

## `sick_generic_caller`

`sick_generic_caller` は SICK picoScan などの 2D LiDAR driver です。rogi_nav 側では driver 自体の計測アルゴリズムを持たず、`sensing/config.yaml` の `sick_picoscan` 設定から hostname、UDP 受信 IP、port、frame、scan topic、角度範囲を組み立てて起動します。

実機 profile では各 LiDAR が `/lidar1/scan`、`/lidar2/scan` のような個別 topic を publish します。後段の `scan_merger` は topic 名だけを見て購読するため、LiDAR 台数や IP を変えた場合は `scan_topics` と driver 設定を同時に合わせます。`publish_frame_id` は TF tree 上に存在している必要があります。

## `scan_merger`

`scan_merger` は複数の `sensor_msgs/msg/LaserScan` を 1 つの仮想 LaserScan に再投影します。入力 scan は各 LiDAR frame 基準ですが、出力は `frame_id` parameter、通常は `base_link` 基準です。publish 周期は `frequency` で決まり、sample 設定では topic 配列 `scan_topics` を `/lidar1/scan` と `/lidar2/scan` にしています。

timer callback ごとに、出力 scan の bin 数を `(angle_max - angle_min) / angle_increment + 1` で作り、全 range を `inf` で初期化します。各入力 scan の各 beam について、range が有限で入力 scan の `range_min/max` 内にあるものだけを点 `(r cos theta, r sin theta, 0)` に変換します。その点を TF で入力 frame から出力 frame に変換し、出力 frame での極座標 `(merged_range, merged_angle)` を再計算します。

再計算した点が出力側の `range_min/max` と `angle_min/max` に入る場合、`merged_angle` から最も近い bin を求めます。同じ bin に複数 LiDAR の点が入ったときは、距離が最小のものを採用します。これは LaserScan の「その方向で最初に当たった障害物」を保つためです。TF が引けない scan はスキップし、全く scan を受けていない場合だけ warning を出して publish しません。

このノードは時間同期を厳密には取りません。各 topic の最新 scan を保持し、publish timer の時点で使えるものを統合します。高速に動くロボットや LiDAR 間の時刻ずれが大きい環境では、`frequency`、driver の publish rate、TF stamp の整合が検出線分の揺れに直結します。

## `line_detector`

`line_detector` は LaserScan から直線、線分、交点を抽出します。後段の `ransac_localizer` は観測線分と地図線分を対応付けるため、ここで出る `line_segments` の品質が補正精度を大きく左右します。

前処理では scan の各 beam を range/angle filter に通し、有限値かつ `LaserScan` の範囲内、さらに parameter の `min_range/max_range` と `min_angle/max_angle` 内にある点だけを 2D 点 `(x, y)` に変換します。この点群を `raw_scan_points_` として保持し、RANSAC の inlier 削除用に `scan_points_` へコピーします。

直線検出は最大 `max_lines` 回繰り返します。各回で現在残っている点から 2 点をランダムに選び、正規化した直線 `a x + b y + c = 0` を作ります。全点との垂直距離を計算し、`distance_threshold` 未満の点数を inlier として数えます。これを `max_iterations` 回試し、inlier 数が最大の直線を候補にします。

候補の inlier 数が `min_inliers` を超えたら、inlier index をシャッフルし、最大 `refinement_sample_count` 点を使って直線を再推定します。再推定は直交最小二乗です。サンプル点の平均と共分散を求め、共分散行列の主軸角を直線方向として、法線 `(a, b)` と切片 `c` を更新します。これにより、ランダムに選んだ 2 点だけで決めた線よりも scan 全体に合う線になります。

直線を 1 本採用した後、その直線から `distance_threshold` 未満の点は `scan_points_` から削除します。これにより、次の RANSAC はまだ説明されていない点から別の直線を探します。壁が長い環境では強い線から順に検出され、ノイズや曲面は inlier 数が足りなければ残っても publish されません。

線分化では、検出済み直線ごとに元の全 scan 点から inlier を再収集します。直線の方向ベクトルに各 inlier を射影して並べ、隣接点間の実距離が `segment_gap_threshold` を超えた場所でクラスタを分割します。各クラスタの先頭と末尾を直線上へ射影し直した点が線分の start/end です。これにより、同一直線上でも障害物で途切れた壁は複数線分として扱われます。

交点 `corners` は検出された無限直線どうしの全ペアから求めます。行列式がほぼ 0 の平行線は無視し、それ以外は `a x + b y + c = 0` の連立方程式を解いて `PoseArray` に入れます。orientation は単位 quaternion で、角の向きは表していません。
