# simple_pure_pursuit

## 役割

`simple_pure_pursuit` は CSV 経路を追従し、`/cmd_vel` を生成します。`FollowPath` action の `path_index` で追従対象の経路を選び、終点付近の減速と停止完了判定は `StopController` に委譲します。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| action server | `follow_path` | `rogi_msgs/action/FollowPath` |
| subscribe | `/localization_pose` | `geometry_msgs/msg/PoseWithCovarianceStamped` |
| subscribe | `/robot_pose` | `geometry_msgs/msg/Pose2D` |
| subscribe | `/odom` | `nav_msgs/msg/Odometry` |
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

## 遅延補償

自己位置推定・通信・モータ応答の遅れを補償するため、制御には推定姿勢そのものではなく、前回 publish した `/cmd_vel`（body 座標の {math}`v_x, v_y, \omega`）で `path.follow.latency_compensation_sec`（{math}`\tau`、既定 0.2 s）だけ等速に進めた予測姿勢を使います。

```{math}
\theta_m=\theta+\tfrac{1}{2}\omega\tau,\qquad
\begin{bmatrix}x'\\y'\end{bmatrix}=
\begin{bmatrix}x\\y\end{bmatrix}+\tau
\begin{bmatrix}\cos\theta_m&-\sin\theta_m\\\sin\theta_m&\cos\theta_m\end{bmatrix}
\begin{bmatrix}v_x\\v_y\end{bmatrix},\qquad
\theta'=\theta+\omega\tau
```

以降の nearest / lookahead の探索、速度指令、終点停止の距離はすべてこの予測姿勢 {math}`(x',y',\theta')` で計算します。`/distance_to_goal` は予測前の推定姿勢から計算します。{math}`\tau=0` で補償を無効にできます。

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

終点付近では、並進速度の大きさを `StopController` の出力に置き換えます。`bang_bang` の P 制御段階では目標方向も現在位置から終点へ向け直します。停止方式ごとの速度計算は [](stop.md) を参照してください。

角速度は最大値で clamp します。

```{math}
\omega_c=\operatorname{clamp}(\omega,-\omega_{\max},\omega_{\max})
```

clamp が発生した場合は並進も縮小します。

```{math}
\gamma=\min\left(1,\frac{\omega_{\max}}{|\omega|}k_{\mathrm{xy}}\right)
```

```{math}
v_x\leftarrow\gamma v_x,\qquad v_y\leftarrow\gamma v_y
```

## 終点停止

終点までの距離、終点 yaw との誤差、および odometry の並進速度と角速度を `StopController` に渡します。停止完了と判定されたら `/cmd_vel` を 0 にし、`FollowPath` action を success にします。判定条件は {ref}`stop-goal-judgement` を参照してください。

## 停止グラフ

`path.follow.graph.enabled` が `true` の場合、終点までの距離が `path.follow.graph.start_distance` 以下になると記録を開始します。記録開始時刻を 0 s として、odometry の並進速度と終点までの距離を制御周期ごとに保存します。一度開始した記録は、ロボットがしきい値の外へ戻っても継続します。`false` の場合は記録もファイル出力も行いません。

最初の有効な odometry sample を記録した時点で、`path.follow.graph.output_directory` 以下にタイムスタンプ付きディレクトリと次の SVG を作成します。走行完了、action のキャンセル、またはノード終了時に、全 sample を使って同じファイルを更新します。しきい値へ到達しなかった場合や、有効な odometry を取得できなかった場合は出力しません。

```text
output/
└── YYYYMMDD_HHMMSS_mmm/
    ├── velocity_vs_time.svg
    └── distance_vs_time.svg
```

| parameter | default | 説明 |
| --- | ---: | --- |
| `path.follow.graph.enabled` | `true` | 停止グラフの記録と出力を有効にする |
| `path.follow.graph.start_distance` | `1.0` | グラフ記録を開始する終点距離 [m] |
| `path.follow.graph.output_directory` | `output` | タイムスタンプ付き出力ディレクトリを作成する親ディレクトリ |

相対パスの `output` は、経路 CSV の場所から検出したリポジトリルートを基準に解決されます。そのため example config の出力先は `<repository>/output` です。リポジトリルートを検出できない場合だけ、launch process の作業ディレクトリを基準にします。起動時、記録開始時、保存完了時のログには、実際に使用する絶対パスを表示します。

## 設定ファイル

`rogi_nav.launch.py` が profile と `config_dir` から parameter を組み立てます。追従制御と停止制御の ROS parameter は `control/config.yaml` にまとめて記述します。

| 設定元 | key / path | 対応 |
| --- | --- | --- |
| `config_dir/path/trajectory/{0..11}.csv` | 経路 CSV | `input.csv.follow_path_files` |
| `localization/config.yaml` | `topics.localization_pose` | `pose_with_covariance_topic` |
| `localization/config.yaml` | `topics.odom` | `odometry_topic` |
| `control/config.yaml` または `control/<profile>/config.yaml` | `simple_pure_pursuit.ros__parameters` | 追従制御・停止制御 parameter |
| `real.yaml` / `sim.yaml` | `launch.components.pure_pursuit.simple_pure_pursuit.enabled` | ノード起動の有効/無効 |
| `real.yaml` / `sim.yaml` | `launch.components.pure_pursuit.simple_pure_pursuit.parameters` | 任意の ROS parameter 上書き |

経路 CSV は 1 行を次の pose として読みます。

```text
x,y,theta
```

`x,y` は m、`theta` は rad です。両ノードとも degree への自動判定・変換はしません。ヘッダーなど数値に変換できない行は読み飛ばします。

`path/wayoints/*.csv`（現在のディレクトリ名は `wayoints`）は経路生成用の編集点です。制御ノードが直接読むのは `trajectory/*.csv` です。test の経路 0・1 は途中から終点 yaw に到達する角度列になっており、終点より手前で回転を終えるよう調整されています。これは CSV の変更で、追従ノードに waypoint 用の新しいパラメータはありません。

launch は固定で 12 本の trajectory を探します。

```{math}
P_i=\operatorname{join}(D_{\mathrm{config}},\mathrm{path/trajectory}/i.csv),
\qquad i=0,\dots,11
```

制御 parameter を profile で上書きする場合は、次のように `parameters` を追加します。

```yaml
launch:
  components:
    control:
      simple_pure_pursuit:
        enabled: true
        parameters:
          path:
            follow:
              lookahead_distance: 0.5
              latency_compensation_sec: 0.2
              velocity:
                max_linear: 1.0
                max_angular: 3.0
              gain:
                rotate: 1.0
                xy_scale_adjust: 1.0
                lateral: 0.5
              graph:
                enabled: true
                start_distance: 1.0
                output_directory: output
```

停止制御 parameter と設定例は [](stop.md) にまとめています。sample は `control/config.yaml`、test / nhk_2027 は `control/real/config.yaml` または `control/sim/config.yaml` から基本値を読み込みます。profile の `parameters` は最上位キー単位の上書きです。例えば `path` を指定すると、基本設定の `path` 全体を置き換えるため、維持したい停止設定なども含めて記述してください。

## 実行中のパラメータ変更

`path.follow.velocity.max_linear`、`path.follow.velocity.max_angular`、`path.follow.latency_compensation_sec` は実行中の変更を制御値へ反映します。有限・非負の double が必要です。他の gain、停止方式、しきい値などは起動時に読み込むため、YAML 編集後にノードを再起動します。
