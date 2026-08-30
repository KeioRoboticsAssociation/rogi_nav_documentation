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

## `emcl2`

`emcl2` は LiDAR scan、`OccupancyGrid`、odom TF を使う Monte Carlo Localization です。基本形は likelihood field model の particle filter で、各 particle が map 上の robot pose 仮説を持ちます。scan が来るたびに odom で particle を動かし、LiDAR hit 点が占有 cell 近傍に来るほど重みを大きくし、重みに基づいて resampling します。

起動後、まず `map` topic から `nav_msgs/msg/OccupancyGrid` を受け取るまで particle filter は初期化されません。map 受信時に `LikelihoodFieldMap` を作り、`initial_pose_x/y/a` に `num_particles` 個の particle を同じ姿勢で置きます。`initialpose` topic を受けた場合、初回は scan と map が揃ってから初期化し、2 回目以降は次の loop で全 particle を指定 pose に再配置します。

尤度場は `OccupancyGrid` の占有 cell、つまり値が 50 より大きい cell から作ります。各占有 cell の周囲 `laser_likelihood_max_dist` まで、距離に応じて 255 から 0 へ減衰する値を持たせます。particle の尤度計算では、各 valid beam の終点を particle pose と LiDAR extrinsics で map 座標に変換し、その位置の尤度場値を足し合わせます。障害物に近い hit が多い particle ほど大きい likelihood になります。

motion update では TF から `odom_frame_id` に対する `base_frame_id` の pose を取得し、前回 odom との差分を求めます。差分がほぼ 0 なら何もしません。移動量は前進距離 `fw_length`、移動方向 `fw_direction`、回転量 `d.t` に分解され、`OdomModel` が距離・回転に比例した標準偏差を計算します。各 particle は同じ odom 差分で動きますが、`odom_fw_dev_per_*` と `odom_rot_dev_per_*` に基づく正規乱数 noise が加わります。

sensor update では scan frame から `base_link` への TF を引き、LiDAR の取り付け位置と yaw を particle 尤度に反映します。LiDAR が上下反転している場合は roll/pitch から `inv` を判定し、beam 角度の並びを反転して扱います。scan は `scan_increment` ごとに間引けるため、処理負荷と精度のトレードオフを調整できます。

この実装は `ExpResetMcl2` を使い、通常の重み更新に加えて非壁貫通率 `alpha` を計算します。particle の一部を抜き出し、scan ray が地図上の壁を貫通して open space に抜けていないかを調べます。貫通していない割合が `alpha` で、`alpha_threshold` を下回ると localization が地図と矛盾しているとみなし、各 particle を `expansion_radius_position` と `expansion_radius_orientation` の範囲でランダムに散らしてから再度 likelihood を掛けます。`sensor_reset` が true の場合は、壁貫通を検出した beam 対から particle pose を直接補正する処理も使われます。

重み合計が十分大きい場合は systematic resampling を行います。累積重み上で等間隔のサンプル点を置き、高重み particle を多く複製します。重み合計が極端に小さい場合は全 particle を等重みに戻します。`global_localization` service は free cell から particle pose をランダムに引き直す simple reset です。

推定 pose は particle の平均です。yaw は通常平均と π ずらした平均の分散を比較し、角度 wrap の影響が小さい方を採用します。共分散は particle 分布から計算され、`localization_pose` として publish されます。同時に `particlecloud`、`alpha`、`map -> odom` TF も publish します。TF は scan stamp に `transform_tolerance` を足した時刻で出します。

## `ransac_localizer`

`ransac_localizer` は `line_detector` が出した観測線分を地図線分に対応付け、odom prediction を線分残差で補正する localizer です。particle filter ではなく、現在 pose 近傍の非線形最小二乗として動きます。線がはっきり見えるフィールドでは、LiDAR 点群を直接 grid に当てるよりも壁方向と壁位置の拘束を強く使えます。

入力地図は `rogi_msgs/msg/Map` の線分だけです。円はこのノードの対応付けには使われません。観測線分を受け取ると、まず線分 message の frame から `base_frame_id` への TF を引き、観測線分の両端を robot base 座標に変換します。odom は `/odom` から最新 pose を保持します。

prediction は odom 差分で作ります。初回は現在の内部 pose をそのまま使い、2 回目以降は `previous_odom_` から最新 `odom_` への相対変化を前回の map pose に合成します。つまり odom が短期の運動を予測し、線分 matching が drift を補正します。

観測線分と地図線分の対応付けでは、観測線分を候補 pose で map 座標に変換し、中点、方向角を求めます。各地図線分について、方向差、地図線への法線距離、線分端からはみ出した量を計算し、`distance + outside + 0.25 * angle` を score にします。方向差が `max_angle_difference` 未満、法線距離と外側距離が `max_association_distance` 未満の中で最小 score の線分を対応として採用します。

最適化は最大 `max_iterations` 回の Gauss-Newton です。対応した地図線分の法線方向に対して、観測線分の両端点がどれだけずれているかを残差 `r` とします。ヤコビアンは pose の `x, y, yaw` に対する残差微分で、Hessian `H` と gradient `g` を加算します。大きな残差は `0.15 / |r|` で重みを落とす robust weight を使い、外れ対応の影響を抑えます。

線分残差だけでなく、prediction から離れすぎないよう odom prior も足します。`odom_translation_stddev` と `odom_rotation_stddev` が prior の強さ、`measurement_stddev` が線分観測の強さです。対応数が `min_correspondences` 未満、または 3x3 線形方程式が特異に近い場合は補正を失敗扱いにし、pose は prediction のまま進めます。

publish 時は `localization_pose` に補正後 pose と簡易共分散を入れます。さらに最新 odom pose の逆変換と補正 pose から `map -> odom` TF を計算して broadcast します。`emcl2` と同時に `map -> odom` を publish すると TF が競合するため、どちらを主 localizer とするか profile 側で整理する必要があります。

## `wheel_odometry`

`wheel_odometry` は Rogidrive の motor position から 4 輪 omni の `odom -> base_link` を積分します。入力は `/rogidrive_status` の multi array で、`motor_names` に一致する motor だけを使います。全 wheel の状態を一度受け取るまでは積分を開始せず、初回は現在 encoder 角を基準値として保存して初期 pose を publish します。

各 status の `pos` は `rogidrive_position_is_revolutions` が true なら revolution 単位として `2π` 倍し、false なら radian として扱います。前回積分角との差分は `wrap_angle_delta` が true の場合 `atan2(sin(delta), cos(delta))` で `[-π, π]` に畳みます。encoder が連続回転量を出す設定では wrap を切る必要があります。

wheel ごとに encoder 差分へ `encoder_signs` と `motor_to_omni_reduction_ratio` を反映し、omni wheel の角度差分にします。接地点の移動量は `wheel_radius * wheel_delta` です。wheel 配置は `wheel_position_angles_deg`、駆動方向は `wheel_drive_angles_deg`、中心から wheel までの距離は `center_to_wheel` で決まります。

body delta は最小二乗で解きます。各 wheel は、body 座標での微小変位 `[dx, dy, dyaw]` が wheel 駆動方向へ投影された量を観測します。行は `[cos(drive), sin(drive), -cos(drive) * wheel_y + sin(drive) * wheel_x]` で、全 wheel の正規方程式 `A^T A x = A^T b` を 3x3 の Cramer 法で解きます。4 輪なら冗長拘束を平均する形になり、1 輪の小さな誤差を多少なら吸収できます。

得られた `dx, dy, dyaw` は body 座標の差分なので、積分時は中点 yaw `yaw + 0.5 * dyaw` で map/odom 座標に回転して `x, y` に足します。yaw は `atan2(sin, cos)` で正規化します。速度は差分を前回 publish からの `dt` で割って `twist` に入れます。共分散は x/y/yaw に小さめ、z/roll/pitch に大きめの固定値を設定しています。

`publish_tf` が true の場合は `odom_frame_id -> base_frame_id` の TF も publish します。localizer はこの odom TF を短期予測として使うため、wheel parameter の符号や wheel 角度がずれていると自己位置推定全体が不安定になります。
