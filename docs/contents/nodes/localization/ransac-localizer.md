# ransac_localizer

## 役割

`ransac_localizer` は観測線分と地図線分を対応付け、odom prediction を線分残差で補正します。最適化対象は 2D pose {math}`x=(p_x,p_y,\theta)` です。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| subscribe | `map` | `rogi_msgs/msg/Map` |
| subscribe | `odom` | `nav_msgs/msg/Odometry` |
| subscribe | `line_segments` | `rogi_msgs/msg/LineSegmentArray` |
| publish | `localization_pose` | `geometry_msgs/msg/PoseWithCovarianceStamped` |
| tf | `map -> odom` | 補正 pose と odom pose から計算 |

## Odom prediction

前回 odom {math}`o_{t-1}`、現在 odom {math}`o_t` から相対変換を求めます。

```{math}
\Delta o=o_{t-1}^{-1}\circ o_t
```

前回 map pose {math}`x_{t-1}` に合成して prediction を作ります。

```{math}
x_0=x_{t-1}\circ\Delta o
```

初回は初期 pose をそのまま prediction とします。

## 線分対応付け

観測線分の両端 {math}`s_0,s_1` を候補 pose {math}`x` で map 座標へ変換します。

```{math}
q_k=R(\theta)s_k+
\begin{bmatrix}p_x\\p_y\end{bmatrix},
\qquad k\in\{0,1\}
```

観測線分の中点と角度は、

```{math}
m=\frac{q_0+q_1}{2},\qquad
\theta_o=\operatorname{atan2}(q_{1y}-q_{0y},q_{1x}-q_{0x})
```

地図線分 {math}`l=(a,b)` の方向 {math}`d=b-a`、長さ {math}`L=\|d\|`、法線 {math}`n=(-d_y/L,d_x/L)` に対し、角度差、法線距離、線分外距離を計算します。

```{math}
\Delta\theta=\min(|\operatorname{wrap}(\theta_o-\theta_l)|,\ |\pi-\operatorname{wrap}(\theta_o-\theta_l)|)
```

```{math}
d_\perp=|n^T(m-a)|
```

```{math}
u=\frac{(m-a)^T d}{L^2},\qquad
d_{\mathrm{out}}=\max(0,\max(-u,u-1))L
```

対応候補の score は、

```{math}
J_{\mathrm{assoc}}=d_\perp+d_{\mathrm{out}}+0.25\Delta\theta
```

です。しきい値内で score 最小の地図線分を対応にします。

## Gauss-Newton 補正

対応済みの地図線分について、観測線分端点 {math}`s` の map 座標は、

```{math}
q=R(\theta)s+p
```

残差は地図線分法線方向の signed distance です。

```{math}
r=n^T(q-a)
```

pose {math}`(p_x,p_y,\theta)` に対する Jacobian は、

```{math}
J=
\begin{bmatrix}
n_x &
n_y &
n_x(-\sin\theta\,s_x-\cos\theta\,s_y)+
n_y(\cos\theta\,s_x-\sin\theta\,s_y)
\end{bmatrix}
```

robust weight は、

```{math}
w=
\frac{1}{\sigma_z^2}
\begin{cases}
1 & |r|<0.15\\
0.15/|r| & |r|\ge 0.15
\end{cases}
```

です。Hessian と gradient を加算します。

```{math}
H\leftarrow H+wJ^TJ,\qquad
g\leftarrow g+wJ^Tr
```

odom prior も対角項として足します。

```{math}
H_{ii}\leftarrow H_{ii}+\frac{1}{\sigma_i^2},\qquad
g_i\leftarrow g_i+\frac{x_i-x_{0i}}{\sigma_i^2}
```

線形方程式を解いて pose を更新します。

```{math}
H\Delta x=-g,\qquad x\leftarrow x+\Delta x
```

対応数が `min_correspondences` 未満、または {math}`H` が特異に近い場合は補正せず prediction を採用します。

## map -> odom

補正後 pose を {math}`x_t`、最新 odom pose を {math}`o_t` とすると、

```{math}
T^{map}_{odom}=x_t\circ o_t^{-1}
```

を TF として publish します。

## 設定ファイル

sample では `example/sample/config/localization/ransac/config.yaml` の `ransac_localizer.ros__parameters` を使います。`rogi_nav.launch.py` は `localization.method == ransac` のとき、この YAML を `ransac_localizer` に渡します。

| key | sample 値 | 数式上の意味 |
| --- | --- | --- |
| `initial_pose_x/y/a` | `0.0` | 初期 pose {math}`x_0` |
| `map_frame_id` | `map` | `localization_pose` frame と TF 親 frame |
| `odom_frame_id` | `odom` | `map -> odom` の child frame |
| `base_frame_id` | `base_link` | 観測線分を変換する基準 frame |
| `max_iterations` | `8` | Gauss-Newton 最大反復回数 |
| `min_correspondences` | `2` | 補正を成立させる最小対応線分数 |
| `max_association_distance` | `0.8` | {math}`d_\perp` と {math}`d_{\mathrm{out}}` のしきい値 |
| `max_angle_difference` | `0.35` | 対応付けの角度差しきい値 |
| `odom_translation_stddev` | `0.15` | odom prior の {math}`\sigma_x,\sigma_y` |
| `odom_rotation_stddev` | `0.10` | odom prior の {math}`\sigma_\theta` |
| `measurement_stddev` | `0.04` | 線分残差 weight の {math}`\sigma_z` |

`example/sample/config/localization/config.yaml` は次を決めます。

| key | sample 値 | 対応 |
| --- | --- | --- |
| `localization.method` | `ransac` | このノードを主 localizer として使う指定 |
| `topics.localization_scan` | `/scan_for_localization` | `line_detector` 入力にも使われる scan topic |
| `topics.odom` | `/odom` | `odom` subscription の remap 先 |
| `topics.localization_pose` | `/localization_pose` | publish 先 |

地図入力は `map/config.yaml` の `topics.raw_map`、sample では `/raw_map` へ remap されます。観測線分 topic は `line_detector` の default `line_segments` を同じ container 内で使います。
