# simple_pure_pursuit

## 役割

`simple_pure_pursuit` は CSV 経路を追従し、`/cmd_vel` を生成します。`FollowPath` action の `path_index` で追従対象の経路を選びます。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| action server | `follow_path` | `rogi_msgs/action/FollowPath` |
| subscribe | `/localization_pose` | `geometry_msgs/msg/PoseWithCovarianceStamped` |
| subscribe | `/robot_pose` | `geometry_msgs/msg/Pose2D` |
| publish | `/cmd_vel` | `geometry_msgs/msg/Twist` |
| publish | `/pure_pursuit_path` | `nav_msgs/msg/Path` |
| publish | `/distance_to_goal` | `std_msgs/msg/Float64` |
| publish | `/current_follow_path_index` | `std_msgs/msg/Int32` |

## 経路点

CSV の各点は、

```{math}
p_i=(x_i,y_i,\theta_i)
```

です。現在 pose を {math}`x=(x_r,y_r,\theta_r)` とします。

## nearest と lookahead

nearest index は全探索です。

```{math}
i_n=\arg\min_i \sqrt{(x_i-x_r)^2+(y_i-y_r)^2}
```

lookahead index は、{math}`i_n` 以降で距離が `lookahead_distance` 以上になる最初の点です。

```{math}
i_l=\min\left\{i\ge i_n\mid \sqrt{(x_i-x_r)^2+(y_i-y_r)^2}\ge L_d\right\}
```

見つからない場合は終点 index を使います。

## robot 座標への変換

map 座標の差分 {math}`d=(x_i-x_r,y_i-y_r)` を robot 座標へ変換します。

```{math}
\begin{bmatrix}
t_x\\t_y
\end{bmatrix}
=
\begin{bmatrix}
\cos\theta_r & \sin\theta_r\\
-\sin\theta_r & \cos\theta_r
\end{bmatrix}
\begin{bmatrix}
x_i-x_r\\
y_i-y_r
\end{bmatrix}
```

lookahead 点へのベクトルを {math}`t_l`、nearest 点へのベクトルを {math}`t_n` とします。nearest 方向成分は、

```{math}
h=\frac{t_l^Tt_n}{t_n^Tt_n+\epsilon}t_n
```

です。制御目標方向は、

```{math}
t=t_l-(1-k_y)h
```

ここで {math}`k_y` は `lateral_gain` です。

## 速度指令

並進速度は目標方向の正規化です。

```{math}
v_x=v_{\max}\frac{t_x}{\|t\|},\qquad
v_y=v_{\max}\frac{t_y}{\|t\|}
```

角速度は yaw error に比例します。

```{math}
\omega=k_\theta\operatorname{wrap}(\theta_{\mathrm{target}}-\theta_r)
```

ここで {math}`k_\theta` は `rotate_gain` です。通常は nearest 点の yaw、lookahead が終点なら終点 yaw を使います。

終点に近いときは減速します。終点距離を {math}`d_g`、`stop_threshold` を {math}`d_s` とすると、

```{math}
\alpha=\frac{d_g}{d_s}
```

```{math}
v_{\mathrm{target}}=v_{\max}\alpha+k_s d_g(1-\alpha)
```

です。{math}`k_s` は `stop_gain` です。

角速度は最大値で clamp します。

```{math}
\omega_c=\operatorname{clamp}(\omega,-\omega_{\max},\omega_{\max})
```

clamp が発生した場合は並進も縮小します。

```{math}
\gamma=\frac{\omega_{\max}}{|\omega|}k_{\mathrm{xy}}
```

```{math}
v_x\leftarrow\gamma v_x,\qquad v_y\leftarrow\gamma v_y
```

## goal 判定

終点 pose を {math}`g=(x_g,y_g,\theta_g)` とすると、完了条件は次です。

```{math}
\sqrt{(x_g-x_r)^2+(y_g-y_r)^2}<d_{\mathrm{goal}}
```

```{math}
|\operatorname{wrap}(\theta_g-\theta_r)|<\theta_{\mathrm{goal}}
```

両方を満たすと `/cmd_vel` を 0 にし、action を success にします。

## 設定ファイル

`simple_pure_pursuit` には専用 YAML はありません。`rogi_nav.launch.py` が profile と `config_dir` から parameter を組み立てます。

| 設定元 | key / path | 対応 |
| --- | --- | --- |
| `config_dir/path/trajectory/{0..11}.csv` | 経路 CSV | `input.csv.follow_path_files` |
| `localization/config.yaml` | `topics.localization_pose` | `pose_with_covariance_topic` |
| `real.yaml` / `sim.yaml` | `launch.components.pure_pursuit.simple_pure_pursuit.enabled` | ノード起動の有効/無効 |
| `real.yaml` / `sim.yaml` | `launch.components.pure_pursuit.simple_pure_pursuit.parameters` | 任意の ROS parameter 上書き |

経路 CSV は 1 行を次の pose として読みます。

```text
x,y,theta
```

launch は固定で 12 本の trajectory を探します。

```{math}
P_i=\operatorname{join}(D_{\mathrm{config}},\mathrm{path/trajectory}/i.csv),
\qquad i=0,\dots,11
```

制御 parameter を profile で上書きする場合は、次のように `parameters` を追加します。

```yaml
launch:
  components:
    pure_pursuit:
      simple_pure_pursuit:
        enabled: true
        parameters:
          path.follow.lookahead_distance: 0.5
          path.follow.velocity.max_linear: 1.0
          path.follow.velocity.max_angular: 3.0
          path.follow.gain.rotate: 1.0
          path.follow.gain.stop: 1.0
          path.follow.gain.xy_scale_adjust: 1.0
          path.follow.gain.lateral: 0.5
          path.follow.threshold.stop: 0.1
          path.follow.goal.dist_threshold: 0.01
          path.follow.goal.yaw_threshold_deg: 57.3
```

現在の sample `real.yaml` / `sim.yaml` には `parameters` が無いため、上の値は実装 default が使われます。
