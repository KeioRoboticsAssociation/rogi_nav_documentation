# emcl2

## 役割

`emcl2` は likelihood field model の Monte Carlo Localization です。particle {math}`x_i=(x_i,y_i,\theta_i)` を多数持ち、odom による予測と LiDAR scan による重み更新を繰り返します。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| subscribe | `scan` | `sensor_msgs/msg/LaserScan` |
| subscribe | `map` | `nav_msgs/msg/OccupancyGrid` |
| subscribe | `initialpose` | `geometry_msgs/msg/PoseWithCovarianceStamped` |
| publish | `localization_pose` | `geometry_msgs/msg/PoseWithCovarianceStamped` |
| publish | `particlecloud` | `geometry_msgs/msg/PoseArray` |
| publish | `alpha` | `std_msgs/msg/Float32` |
| service | `global_localization` | `std_srvs/srv/Empty` |
| tf | `map -> odom` | 推定 pose と odom pose から計算 |

## 尤度場

`OccupancyGrid` の占有 cell {math}`m(q)>50` から尤度場 {math}`L(q)` を作ります。占有 cell から grid 距離 {math}`d` だけ離れた cell の値は、実装上は x/y の最大距離に対する線形減衰です。

```{math}
L(q)=\max_o 255\left(1-\frac{d_\infty(q,o)}{R}\right)
```

ここで {math}`o` は占有 cell、{math}`R=\lceil\mathrm{laser\_likelihood\_max\_dist}/\Delta\rceil`、{math}`\Delta` は map resolution です。範囲外は 0 です。

## Motion update

odom から前回 pose {math}`o_{t-1}` と現在 pose {math}`o_t` の差分を求めます。

```{math}
\Delta o=o_t-o_{t-1}=(\Delta x,\Delta y,\Delta\theta)
```

並進距離と移動方向は、

```{math}
l=\sqrt{\Delta x^2+\Delta y^2},\qquad
\psi=\operatorname{atan2}(\Delta y,\Delta x)-\theta_{t-1}^{odom}
```

です。odom noise の標準偏差は、

```{math}
\sigma_l=\sqrt{|l|\sigma_{ff}^2+|\Delta\theta|\sigma_{fr}^2}
```

```{math}
\sigma_\theta=\sqrt{|l|\sigma_{rf}^2+|\Delta\theta|\sigma_{rr}^2}
```

です。各 particle は正規乱数 {math}`\epsilon_l\sim N(0,\sigma_l^2)`、{math}`\epsilon_\theta\sim N(0,\sigma_\theta^2)` を使って移動します。

```{math}
x_i\leftarrow x_i+(l+\epsilon_l)\cos(\theta_i+\psi+\epsilon_\theta)
```

```{math}
y_i\leftarrow y_i+(l+\epsilon_l)\sin(\theta_i+\psi+\epsilon_\theta)
```

```{math}
\theta_i\leftarrow\operatorname{wrap}(\theta_i+\Delta\theta+\epsilon_\theta)
```

## Sensor update

LiDAR の base frame 内 pose を {math}`T_L^B=(x_L,y_L,\theta_L)` とします。particle {math}`x_i` 上での LiDAR 位置は、

```{math}
\begin{bmatrix}x_L^M\\y_L^M\end{bmatrix}
=
\begin{bmatrix}x_i\\y_i\end{bmatrix}
+
R(\theta_i)
\begin{bmatrix}x_L\\y_L\end{bmatrix}
```

beam {math}`k` の hit 点は、

```{math}
z_{ik}=
\begin{bmatrix}x_L^M\\y_L^M\end{bmatrix}
+r_k
\begin{bmatrix}
\cos(\theta_i+\theta_L+\phi_k)\\
\sin(\theta_i+\theta_L+\phi_k)
\end{bmatrix}
```

です。particle likelihood は valid beam の尤度場値の和です。

```{math}
\ell_i=\sum_{k\in V} L(z_{ik})
```

重みは乗算更新されます。

```{math}
w_i\leftarrow w_i\ell_i
```

その後、重み和 {math}`S=\sum_i w_i` が十分大きい場合だけ正規化します。

```{math}
w_i\leftarrow\frac{w_i}{S}
```

## Expansion reset

`ExpResetMcl2` は壁貫通率を使って破綻を検出します。抽出した particle 集合 {math}`P_s` について、scan ray が地図上の壁を貫通した particle 数を {math}`n_p`、検査数を {math}`n` とします。

```{math}
\alpha=\frac{n-n_p}{n}
```

{math}`\alpha < \alpha_{\mathrm{th}}` の場合、全 particle を局所的に散らします。

```{math}
x_i\leftarrow x_i+\delta_r\cos\delta_\psi,\qquad
y_i\leftarrow y_i+\delta_r\sin\delta_\psi
```

```{math}
\theta_i\leftarrow\theta_i+\delta_\theta
```

ここで、

```{math}
\delta_r\in[-r_e,r_e],\quad
\delta_\psi\in[-\pi,\pi],\quad
\delta_\theta\in[-\theta_e,\theta_e]
```

です。{math}`r_e` は `expansion_radius_position`、{math}`\theta_e` は `expansion_radius_orientation` です。

## Resampling と推定値

正規化後は systematic resampling を行います。累積分布 {math}`C_i=\sum_{j\le i}w_j` に対し、

```{math}
u_m=u_0+\frac{m}{N},\qquad m=0,\dots,N-1
```

を置き、{math}`C_i\ge u_m` となる particle を複製します。

推定 pose は particle 平均です。

```{math}
\bar{x}=\frac{1}{N}\sum_i x_i,\qquad
\bar{y}=\frac{1}{N}\sum_i y_i
```

yaw は wrap の影響を避けるため、通常平均と {math}`\pi` shift した平均の分散を比較して小さい方を採用します。共分散は particle 分布から計算し、`localization_pose` に入れます。

## 設定ファイル

sample では `example/sample/config/localization/emcl2/config.yaml` の `emcl2.ros__parameters` を使います。`rogi_nav.launch.py` は `localization.method == emcl2` のとき、この YAML を `emcl2` composable node に渡します。

| key | sample 値 | 数式上の意味 |
| --- | --- | --- |
| `odom_freq` | `160` | filter loop 周波数 {math}`f`、周期 {math}`T=1/f` |
| `transform_tolerance` | `0.2` | `map -> odom` TF stamp の未来 offset |
| `global_frame_id` | `map` | 出力 pose / TF の global frame |
| `odom_frame_id` | `odom` | odom frame |
| `base_frame_id` | `base_link` | robot base frame |
| `laser_min_range`, `laser_max_range` | `0.0`, large | valid beam 集合 {math}`V` の range 条件 |
| `scan_increment` | `1` | beam 間引き幅 |
| `initial_pose_x/y/a` | `0.0` | 初期 particle pose |
| `num_particles` | `1000` | particle 数 {math}`N` |
| `alpha_threshold` | `0.8` | expansion reset 条件 {math}`\alpha<\alpha_{\mathrm{th}}` |
| `expansion_radius_position` | `0.05` | reset 時の位置揺らし半径 {math}`r_e` |
| `expansion_radius_orientation` | `0.1` | reset 時の角度揺らし幅 {math}`\theta_e` |
| `extraction_rate` | `0.1` | 壁貫通率を計算する particle 抽出率 |
| `range_threshold` | `0.3` | 壁貫通判定の連続角度幅 |
| `sensor_reset` | `false` | 壁貫通 beam から pose を直接補正するか |
| `odom_fw_dev_per_fw` | `0.05` | {math}`\sigma_{ff}` |
| `odom_fw_dev_per_rot` | `0.0001` | {math}`\sigma_{fr}` |
| `odom_rot_dev_per_fw` | `0.03` | {math}`\sigma_{rf}` |
| `odom_rot_dev_per_rot` | `0.05` | {math}`\sigma_{rr}` |
| `laser_likelihood_max_dist` | `0.3` | 尤度場の影響距離 |

`example/sample/config/localization/config.yaml` は localizer 共通の選択と topic remap を持ちます。

| key | sample 値 | 対応 |
| --- | --- | --- |
| `localization.method` | `ransac` | `emcl2` を主 localizer にするなら `emcl2` |
| `topics.localization_scan` | `/scan_for_localization` | `scan` subscription の remap 先 |
| `topics.odom` | `/odom` | odom TF / topic 名の前提 |
| `topics.localization_pose` | `/localization_pose` | `localization_pose` publish 先 |

profile 側の `launch.components.localization.emcl2.enabled` が false なら、`method=emcl2` でも起動しません。
