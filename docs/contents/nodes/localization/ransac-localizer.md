# ransac_localizer

## 概要

`ransac_localizer` は、odomで予測した2D姿勢 `(x, y, yaw)` を、LiDARの観測線分と地図線分の対応から補正します。点群から線分を検出するRANSACは前段の [`line_detector`](../sensing/line-detector.md) が行います。このノードは観測線分のペアを全列挙するため、地図全体をランダム探索する処理ではありません。

## 処理の流れ

線分メッセージを受信すると、次の順に処理します。

1. 前回の補正姿勢へodomの相対移動を加え、予測姿勢を作ります。
2. 観測線分を `base_link` 座標へ変換し、短い線分を除外します。
3. 非平行な線分を2本ずつ選び、各ペアから姿勢候補を最適化します。
4. 選択した2本が距離・角度のインライア条件を満たすことを確認します。
5. 候補を全観測線分で評価し、最小scoreの姿勢を採用します。
6. `localization_pose` と `map -> odom` を配信します。

候補生成には非平行な2本が必要です。平行線だけでは壁に沿う位置を決められないため、線分補正を行いません。

## 候補の評価

観測線分ごとに、対応する地図線分との端点距離と角度差からコスト `J_i` を計算し、上限を1に制限します。姿勢候補のscoreは観測線分長 `L_i` で重み付けします。

```{math}
J_{pose}=
\frac{N}{\sum_i L_i}
\sum_i L_i\min(J_i,1)
+10^{-3}J_{odom}
```

長い線分との不一致ほど強く評価されるため、短い断片線分の影響を抑えられます。`N / ΣL_i` は平均重みを1に保つための正規化です。インライア数が `min_correspondences` 未満の候補は棄却します。

最適化には、選択した2本の端点から地図直線への法線距離と、弱いodom priorを使用します。全観測線分は候補評価に使いますが、最終最適化に使うのは選択された2本です。

## 直交地図の制約

`map_is_orthogonal: true` の場合、候補に選んだ観測線分2本が90°に近いか確認します。90°との差が `orthogonal_angle_tolerance` を超えるペアは、最適化前に棄却します。

```yaml
map_is_orthogonal: true
orthogonal_angle_tolerance: 6.0  # degree
```

直交壁のみで構成された地図では、斜めの誤検出や同一方向に近い線分から作られる誤候補を減らせます。斜め壁を含む地図では `false` にしてください。

## 状態と再捕捉

状態は `/localization/ransac_state` に配信されます。

| 状態 | 動作 |
| --- | --- |
| `initializing` | odomで姿勢を伝播し、再捕捉用条件で初回捕捉を試みます。 |
| `odom_only` | RANSAC補正を停止し、odomだけで姿勢を更新します。 |
| `ransac_acquiring` | `odom_only` からの切替後、再捕捉用条件で捕捉を試みます。 |
| `ransac_tracking` | 通常条件で線分補正を行います。 |
| `ransac_fallback` | odomで姿勢を伝播しながら、再捕捉用条件で自動復帰を試みます。 |

通常条件で候補が得られないと `ransac_fallback` へ移り、再捕捉に成功すると `ransac_tracking` へ戻ります。`/localization/set_ransac_enabled` へ `false` を送ると `odom_only` へ、`odom_only` 中に `true` を送ると `ransac_acquiring` へ切り替わります。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| subscribe | `map` | `rogi_msgs/msg/Map` |
| subscribe | `odom` | `nav_msgs/msg/Odometry` |
| subscribe | `line_segments` | `rogi_msgs/msg/LineSegmentArray` |
| publish | `localization_pose` | `geometry_msgs/msg/PoseWithCovarianceStamped` |
| publish | `/localization/ransac_state` | `std_msgs/msg/String` |
| service | `/localization/set_ransac_enabled` | `std_srvs/srv/SetBool` |
| TF | `map -> odom` | 補正姿勢と最新odomから計算 |

観測線分のTF変換には現在利用できる最新TFを使用します。線分時刻でのTF補間は行いません。

使用するオドメトリは、統合 launch が `localization/<profile>/config.yaml` の `topics.odom` を `odom` に remap して切り替えます（`ransac/config.yaml` には topic のパラメータはありません）。
`map -> odom` は購読中のオドメトリから計算するため、`odom -> base_link` の TF も同じオドメトリが出している必要があります（`odom_frame_id` とオドメトリの `frame_id` を一致させる）。

| profile | `topics.odom` | `odom -> base_link` TF |
| --- | --- | --- |
| real | `/raw_pose/odom`（MCU の IMU+エンコーダ推定を `pose2d_to_odometry` で変換） | `pose2d_to_odometry`（`publish_tf: true`）。`wheel_odometry` は `/odom` のみ配信し TF は出さない |
| sim | `/odom`（Gazebo 真値にドリフトを加えたもの） | Gazebo 側の `odom_tf_broadcaster` |

## パラメータ

角度パラメータの単位は、`initial_pose_a` だけrad、それ以外はdegreeです。以下はsample設定値です。

### 通常条件

| key | 値 | 内容 |
| --- | ---: | --- |
| `max_iterations` | `8` | Gauss–Newtonの最大反復回数 |
| `min_correspondences` | `2` | 候補に必要な最小インライア数 |
| `max_association_distance` | `0.10` | 地図線分との最大距離 [m] |
| `max_angle_difference` | `10.0` | 地図線分との最大角度差 [degree] |
| `parallel_angle_tolerance` | `6.0` | この角度差以下のペアを平行として除外 [degree] |
| `min_line_length` | `0.05` | 使用する観測線分の最小長 [m] |
| `map_is_orthogonal` | `false` | 直交ペア制約の有効化 |
| `orthogonal_angle_tolerance` | `6.0` | 90°から許容する差 [degree] |
| `score_distance_weight` | `1.0` | 対応付け時の法線距離の重み |
| `score_outside_weight` | `1.0` | 対応付け時の線分外距離の重み |
| `score_angle_weight` | `1.0` | 対応付け時の角度差の重み |
| `score_distance_threshold` | `0.10` | インライア評価の距離尺度 [m] |
| `score_angle_threshold` | `6.0` | インライア評価の角度尺度 [degree] |
| `odom_translation_stddev` | `0.15` | odom priorの並進標準偏差 [m] |
| `odom_rotation_stddev` | `6.0` | odom priorの回転標準偏差 [degree] |
| `measurement_stddev` | `0.04` | 線分残差の標準偏差 [m] |

frameと初期姿勢は `map_frame_id`、`odom_frame_id`、`base_frame_id`、`initial_pose_x/y/a` で指定します。

### 再捕捉条件

初期捕捉、`odom_only` からの切替、`ransac_fallback` からの復帰では以下を使用します。

| key | 値 |
| --- | ---: |
| `acquisition_max_association_distance` | `0.30 m` |
| `acquisition_max_angle_difference` | `30.0 degree` |
| `acquisition_parallel_angle_tolerance` | `3.0 degree` |
| `acquisition_min_line_length` | `0.025 m` |
| `acquisition_score_distance_threshold` | `0.30 m` |
| `acquisition_score_angle_threshold` | `18.0 degree` |

## 注意点

- 初期姿勢付近で地図線分を対応付けるため、地図全体からのglobal localizationは行いません。
- 線分地図は壁の中心ではなく、LiDARが観測する表面に合わせる必要があります。壁厚の半分だけ地図線と観測面がずれると、同じ量の位置バイアスが残ります。
- 出力covarianceは最適化結果から計算しておらず、x・yに `measurement_stddev²`、yawに `odom_rotation_stddev²` を設定します。
- 地図に含まれる円は使用しません。

設定例は `example/sample/config/localization/ransac/config.yaml`、実装は [`ransac_localizer.cpp`](https://github.com/KeioRoboticsAssociation/rogi_nav/blob/main/rogi_localization/2d_lidar/ransac_matching/src/ransac_localizer.cpp) を参照してください。
