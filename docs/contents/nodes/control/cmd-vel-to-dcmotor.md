# cmd_vel_to_dcmotor_node

## 役割

`cmd_vel_to_dcmotor_node` は body velocity `/cmd_vel` を Rogidrive の motor velocity command に変換します。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| subscribe | `/cmd_vel` | `geometry_msgs/msg/Twist` |
| publish | `/rogidrive_cmd` | Rogidrive motor command |
| parameter | `wheel_radius`, `center_to_wheel` | wheel 幾何 |
| parameter | `wheel_position_angles_deg`, `wheel_drive_angles_deg` | wheel 配置と駆動方向 |
| parameter | `motor_signs`, `motor_to_omni_reduction_ratio` | motor 変換 |

## Wheel kinematics

body velocity を、

```{math}
v=
\begin{bmatrix}
v_x\\v_y\\\omega
\end{bmatrix}
```

とします。実装では物理配置に合わせて yaw だけ反転します。

```{math}
\omega'=-\omega
```

wheel 位置と駆動方向は、

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

です。wheel 位置での robot 速度は、

```{math}
v_i=
\begin{bmatrix}
v_x-\omega' r_{iy}\\
v_y+\omega' r_{ix}
\end{bmatrix}
```

接地点速度は駆動方向への射影です。

```{math}
s_i=u_i^Tv_i
```

omni wheel 角速度は、

```{math}
\dot{\phi}_i=\frac{s_i}{\rho}
```

ここで {math}`\rho` は `wheel_radius` です。motor 角速度は、

```{math}
\dot{m}_i=\operatorname{clamp}\left(\eta_iG\dot{\phi}_i,\ -m_{\max},\ m_{\max}\right)
```

です。{math}`\eta_i` は `motor_signs[i]`、{math}`G` は `motor_to_omni_reduction_ratio`、{math}`m_{\max}` は `max_motor_speed_rad_s` です。

## Timeout

最後の `/cmd_vel` 受信からの経過時間を {math}`\Delta t` とすると、

```{math}
\Delta t > t_{\mathrm{timeout}}
```

で timeout です。`stop_on_timeout=true` の場合、各 motor に速度 0 を 1 回 publish し、古い速度指令は繰り返しません。

## 設定ファイル

`cmd_vel_to_dcmotor_node` はパッケージ同梱の `rogi_control/cmd_vel_to_dcmotor/config/cmd_vel_to_dcmotor.yaml` を使います。sample の `real.yaml` では有効、`sim.yaml` では無効です。

| key | default 値 | 数式上の意味 |
| --- | --- | --- |
| `cmd_vel_topic` | `/cmd_vel` | 入力 topic |
| `motor_command_topic` | `/rogidrive_cmd` | 出力 topic |
| `motor_names` | `[wheel_fl, wheel_rl, wheel_rr, wheel_fr]` | motor command の publish 名 |
| `wheel_radius` | `0.065` | {math}`\rho` |
| `center_to_wheel` | `0.328` | {math}`R` |
| `motor_to_omni_reduction_ratio` | `19.2` | {math}`G` |
| `wheel_position_angles_deg` | `[45,135,-135,-45]` | {math}`\alpha_i` |
| `wheel_drive_angles_deg` | `[135,-135,-45,45]` | {math}`\beta_i` |
| `motor_signs` | `[1,1,1,1]` | {math}`\eta_i` |
| `max_motor_speed_rad_s` | `200.0` | clamp 上限 {math}`m_{\max}` |
| `publish_period_sec` | `0.02` | command publish 周期 |
| `cmd_vel_timeout_sec` | `0.5` | timeout 条件 {math}`t_{\mathrm{timeout}}` |
| `stop_on_timeout` | `true` | timeout 時に停止 command を出す |
| `disable_on_zero` | `false` | ほぼ 0 の motor を disable 扱いにする |
| `zero_epsilon` | `0.0001` | 0 判定しきい値 |

profile 側の起動 key は次です。

```yaml
launch:
  components:
    control:
      cmd_vel_to_dcmotor:
        enabled: true
```

`wheel_odometry` と同じ wheel 順序・幾何を使います。特に `motor_names[i]` と {math}`\alpha_i,\beta_i,\eta_i` の対応がずれると、特定 wheel だけ逆向きまたは別位置の wheel として計算されます。
