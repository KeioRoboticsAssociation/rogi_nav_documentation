# wheel_odometry

## 役割

`wheel_odometry` は Rogidrive encoder から omni wheel odometry を計算します。全 wheel の encoder を受け取った後、差分を body 座標の {math}`(\Delta x,\Delta y,\Delta\theta)` に変換して積分します。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| subscribe | `/rogidrive_status` | Rogidrive status |
| publish | `/odom` | `nav_msgs/msg/Odometry` |
| tf | `odom -> base_link` | `publish_tf=true` の場合 |

## Encoder 差分

motor position {math}`q_i` は、`rogidrive_position_is_revolutions=true` なら revolution から radian へ変換します。

```{math}
\phi_i=2\pi q_i
```

false の場合は {math}`\phi_i=q_i` です。前回積分値との差分は、

```{math}
\Delta\phi_i=\phi_i-\phi_{i,\mathrm{prev}}
```

`wrap_angle_delta=true` なら、

```{math}
\Delta\phi_i\leftarrow\operatorname{atan2}(\sin\Delta\phi_i,\cos\Delta\phi_i)
```

です。omni wheel 側の角度差分は、

```{math}
\Delta\omega_i=\frac{s_i\Delta\phi_i}{G}
```

ここで {math}`s_i` は `encoder_signs[i]`、{math}`G` は `motor_to_omni_reduction_ratio` です。

## Wheel constraint

wheel 位置角を {math}`\alpha_i`、駆動方向角を {math}`\beta_i`、中心から wheel までの距離を {math}`R` とします。

```{math}
r_i=
\begin{bmatrix}
R\cos\alpha_i\\
R\sin\alpha_i
\end{bmatrix},
\qquad
u_i=
\begin{bmatrix}
\cos\beta_i\\
\sin\beta_i
\end{bmatrix}
```

body delta {math}`\xi=(\Delta x,\Delta y,\Delta\theta)^T` による wheel 接地点の移動は、

```{math}
\begin{bmatrix}
\Delta x-\Delta\theta r_{iy}\\
\Delta y+\Delta\theta r_{ix}
\end{bmatrix}
```

です。これを駆動方向へ射影した量が wheel の接地点移動量 {math}`b_i` になります。

```{math}
u_i^T
\begin{bmatrix}
\Delta x-\Delta\theta r_{iy}\\
\Delta y+\Delta\theta r_{ix}
\end{bmatrix}
=
\rho\Delta\omega_i
```

ここで {math}`\rho` は `wheel_radius` です。行列の 1 行は、

```{math}
A_i=
\begin{bmatrix}
\cos\beta_i &
\sin\beta_i &
-\cos\beta_i r_{iy}+\sin\beta_i r_{ix}
\end{bmatrix}
```

右辺は、

```{math}
b_i=\rho\Delta\omega_i
```

です。

## 最小二乗

全 wheel について、

```{math}
A\xi=b
```

を作り、正規方程式で解きます。

```{math}
(A^TA)\xi=A^Tb
```

実装では 3x3 の Cramer 法で解きます。行列式が小さい場合は解けないため、その周期の odometry 更新をスキップします。

## 積分

body 座標の差分 {math}`(\Delta x,\Delta y,\Delta\theta)` は、中点 yaw で odom 座標へ回転して積分します。

```{math}
\theta_m=\theta+\frac{1}{2}\Delta\theta
```

```{math}
x\leftarrow x+\cos\theta_m\Delta x-\sin\theta_m\Delta y
```

```{math}
y\leftarrow y+\sin\theta_m\Delta x+\cos\theta_m\Delta y
```

```{math}
\theta\leftarrow\operatorname{wrap}(\theta+\Delta\theta)
```

速度は {math}`dt` で割ります。

```{math}
v_x=\frac{\Delta x}{dt},\qquad
v_y=\frac{\Delta y}{dt},\qquad
\omega=\frac{\Delta\theta}{dt}
```

## 設定ファイル

`wheel_odometry` はパッケージ同梱の `rogi_localization/odometry/wheel_odometry/config/wheel_odometry.yaml` を使います。`rogi_nav.launch.py` は sample profile から選んだ初期 pose だけを追加で上書きします。

| key | sample/default 値 | 数式上の意味 |
| --- | --- | --- |
| `rogidrive_status_topic` | `/rogidrive_status` | encoder 入力 topic |
| `odom_topic` | `/odom` | odometry publish topic |
| `odom_frame_id` | `odom` | odom message frame / TF 親 |
| `base_frame_id` | `base_link` | child frame |
| `initial_pose_x/y/a` | profile 由来 | 積分初期値 {math}`(x,y,\theta)` |
| `motor_names` | `[wheel_fl, wheel_rl, wheel_rr, wheel_fr]` | status から使う motor 名 |
| `wheel_radius` | `0.065` | {math}`\rho` |
| `center_to_wheel` | `0.328` | {math}`R` |
| `motor_to_omni_reduction_ratio` | `19.2` | {math}`G` |
| `wheel_position_angles_deg` | `[45,135,-135,-45]` | {math}`\alpha_i` |
| `wheel_drive_angles_deg` | `[135,-135,-45,45]` | {math}`\beta_i` |
| `encoder_signs` | `[1,1,1,1]` | {math}`s_i` |
| `rogidrive_position_is_revolutions` | `true` | {math}`q_i` を revolution として扱う |
| `wrap_angle_delta` | `true` | encoder 差分を {math}`[-\pi,\pi]` に畳む |
| `publish_tf` | `true` | `odom -> base_link` TF を publish |

profile 側では `launch.components.localization.wheel_odometry.enabled` が起動可否です。sample の `sim.yaml` では false、`real.yaml` では true です。

`cmd_vel_to_dcmotor_node` と wheel 幾何が一致していないと、command と odometry が逆向きになります。少なくとも次の配列は同じ順序で揃えます。

```{math}
\{\mathrm{motor\_names},\alpha_i,\beta_i,G,\rho,R\}_{cmd}
=
\{\mathrm{motor\_names},\alpha_i,\beta_i,G,\rho,R\}_{odom}
```
