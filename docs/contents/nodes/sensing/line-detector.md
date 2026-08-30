# line_detector

## 役割

`line_detector` は `LaserScan` を 2D 点群へ変換し、RANSAC で直線を検出し、直線上の点列を線分へ分割します。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| subscribe | `scan` | `sensor_msgs/msg/LaserScan` |
| publish | `lines` | `rogi_msgs/msg/LineArray` |
| publish | `line_segments` | `rogi_msgs/msg/LineSegmentArray` |
| publish | `corners` | `geometry_msgs/msg/PoseArray` |
| parameter | `max_iterations`, `max_lines`, `min_inliers` | RANSAC 条件 |
| parameter | `distance_threshold` | inlier 距離しきい値 {math}`d_{\mathrm{th}}` |
| parameter | `segment_gap_threshold` | 線分分割しきい値 {math}`g_{\mathrm{th}}` |

## scan 点変換

beam index {math}`i` の角度と点は、

```{math}
\theta_i=\theta_{\min}+i\Delta\theta
```

```{math}
p_i=
\begin{bmatrix}
x_i\\y_i
\end{bmatrix}
=
\begin{bmatrix}
r_i\cos\theta_i\\
r_i\sin\theta_i
\end{bmatrix}
```

です。range と angle filter を通った点だけ使います。

```{math}
r_{\min}^{msg}\le r_i\le r_{\max}^{msg},\quad
r_{\min}^{param}<r_i<r_{\max}^{param},\quad
\theta_{\min}^{param}\le\theta_i\le\theta_{\max}^{param}
```

## RANSAC

2 点 {math}`p_1=(x_1,y_1)`、{math}`p_2=(x_2,y_2)` から直線を作ります。

```{math}
a=y_1-y_2,\qquad b=x_2-x_1,\qquad c=x_1y_2-x_2y_1
```

正規化後の直線は {math}`ax+by+c=0`、{math}`a^2+b^2=1` です。

```{math}
(a,b,c)\leftarrow\frac{(a,b,c)}{\sqrt{a^2+b^2}}
```

点 {math}`p_j` の距離は、

```{math}
d_j=|a x_j+b y_j+c|
```

inlier 集合は、

```{math}
I=\{j\mid d_j<d_{\mathrm{th}}\}
```

です。`max_iterations` 回の候補から {math}`|I|` 最大の直線を選び、{math}`|I|>\mathrm{min\_inliers}` の場合に採用します。

## 直交最小二乗 refine

inlier のサンプル集合 {math}`I_s` から平均と共分散を求めます。

```{math}
\mu=\frac{1}{n}\sum_{j\in I_s}p_j
```

```{math}
\Sigma=\sum_{j\in I_s}(p_j-\mu)(p_j-\mu)^T
=
\begin{bmatrix}
\sigma_{xx}&\sigma_{xy}\\
\sigma_{xy}&\sigma_{yy}
\end{bmatrix}
```

直線方向角は共分散の主軸です。

```{math}
\theta_{\mathrm{line}}=
\frac{1}{2}\operatorname{atan2}(2\sigma_{xy},\sigma_{xx}-\sigma_{yy})
```

更新後の直線係数は、

```{math}
a=-\sin\theta_{\mathrm{line}},\qquad
b=\cos\theta_{\mathrm{line}},\qquad
c=-(a\mu_x+b\mu_y)
```

採用後は inlier を削除して次の線を探します。

## 線分化

直線方向ベクトルと基準点を、

```{math}
u=
\begin{bmatrix}
-b\\a
\end{bmatrix},
\qquad
p_0=
\begin{bmatrix}
-ac\\-bc
\end{bmatrix}
```

とします。inlier 点を射影します。

```{math}
t_j=(p_j-p_0)^T u
```

{math}`t_j` で sort し、隣接点距離が次を満たす場所で分割します。

```{math}
\|p_{j+1}-p_j\|>g_{\mathrm{th}}
```

各クラスタ端の射影値から線分を作ります。

```{math}
p_s=p_0+t_{\min}u,\qquad p_e=p_0+t_{\max}u
```

## corner

2 直線の交点は、

```{math}
D=a_1b_2-a_2b_1
```

```{math}
x=\frac{b_1c_2-b_2c_1}{D},\qquad
y=\frac{c_1a_2-c_2a_1}{D}
```

です。{math}`|D|<10^{-8}` は平行として無視します。

## 設定ファイル

sample では `example/sample/config/sensing/config.yaml` の `line_detector.ros__parameters` を使います。

| key | sample 値 | 数式上の意味 |
| --- | --- | --- |
| `max_iterations` | `100` | RANSAC 試行回数 |
| `max_lines` | `10` | 検出する最大直線数 |
| `min_inliers` | `10` | 採用条件 {math}`|I|>\mathrm{min\_inliers}` |
| `refinement_sample_count` | `30` | refine に使う最大 inlier 数 |
| `distance_threshold` | `0.02` | inlier 条件 {math}`d_j<d_{\mathrm{th}}` |
| `segment_gap_threshold` | `0.5` | 線分分割条件 {math}`g_{\mathrm{th}}` |
| `min_range`, `max_range` | `0.30`, `20.0` | scan 点 filter |
| `min_angle`, `max_angle` | `-π`, `π` | scan 点 filter |

`rogi_nav.launch.py` は同じ値から `refinement_sample_count` を抜き出し、launch argument `ransac_refinement_sample_count` としても渡します。結果として `sensing_config_path` の値を読み込んだ後、この値だけ明示上書きされます。

```{math}
N_{\mathrm{refine}} \leftarrow
\mathrm{sensing.yaml}[\mathrm{line\_detector}][\mathrm{refinement\_sample\_count}]
```

入力 topic は `localization/config.yaml` の `topics.localization_scan` で決まり、sample では `/scan_for_localization` です。profile 側では `launch.components.sensing.line_detector.enabled` が起動可否です。
