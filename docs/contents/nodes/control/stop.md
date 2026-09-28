# stop

## 役割

`stop` は `simple_pure_pursuit` の終点接近時に並進目標速度を生成し、停止完了を判定する `StopController` です。独立した ROS node ではなく、`rogi_control/stop/stop.hpp` を include して使用します。

停止方式は `path.follow.stop.mode` で選択します。

| mode | 概要 | 主に使う情報 |
| --- | --- | --- |
| `distance_interpolation` | 終点距離による速度補間 | 終点距離 |
| `velocity_ff` | 制動距離から速度を先に決める速度 FF | 終点距離、最大減速度 |
| `bang_bang` | 一定速度保持から終点への P 制御へ切り替える | 終点距離、切替後の経過時間 |

既定値は `distance_interpolation` です。mode は起動時に読み込まれ、存在しない文字列を指定すると node の初期化を失敗させます。

## 記号

以降では次の記号を使います。

| 記号 | 意味 | 対応 parameter |
| --- | --- | --- |
| {math}`d_g` | 現在位置から経路終点までの距離 | ― |
| {math}`d_s` | 選択した mode へ切り替える終点距離 | 各 mode の `switching_distance` |
| {math}`d_{goal}` | 停止完了とみなす位置許容差 | `path.follow.goal.dist_threshold` |
| {math}`d` | 速度計算に使う残り制動距離 | ― |
| {math}`v_{max}` | 並進速度上限 | `path.follow.velocity.max_linear` |
| {math}`v_k` | odometry から得た現在並進速度 | ― |
| {math}`v_{cmd,k}` | 今回出力する並進目標速度 | ― |
| {math}`\Delta t` | 制御周期 | `control_period_ms / 1000` |
| {math}`a_{dec}` | 速度 FF の最大減速度の大きさ | `path.follow.stop.velocity_ff.max_deceleration` |

`distance_interpolation` と `velocity_ff`、および未切替の `bang_bang` では、終点距離が切替距離以上なら pure pursuit の並進速度上限をそのまま返します。

```{math}
v_{cmd}=v_{max}\qquad(d_g\ge d_s)
```

{math}`d_g<d_s` になったときだけ、選択した停止アルゴリズムへ切り替えます。`velocity_ff` と `bang_bang` の P 制御段階では、位置許容差の内側で速度入力が 0 になるよう、次の残り制動距離を使います。

```{math}
d=\max(0,d_g-d_{goal})
```

現在並進速度は停止完了判定に使います。現行の3方式の目標速度式は現在速度を参照しません。`/odom` の body velocity から計算します。

```{math}
v_k=\sqrt{v_x^2+v_y^2}
```

## distance_interpolation

従来の停止ロジックです。減速開始距離を {math}`d_s`、停止 gain を {math}`k_s` とします。

```{math}
v_{cmd}=\begin{cases}
v_{max} & (d_g\ge d_s)\\
\min\left(v_{max},\ v_{max}\alpha+k_s d_g(1-\alpha)\right) & (d_g<d_s)
\end{cases}
```

```{math}
\alpha=\operatorname{clamp}\left(\frac{d_g}{d_s},0,1\right)
```

{math}`d_s` は `path.follow.stop.distance_interpolation.switching_distance`、{math}`k_s` は `path.follow.stop.distance_interpolation.gain` です。現在速度をフィードバックしないため単純ですが、実機の応答遅れや慣性によって停止位置が変わります。

## velocity_ff

一定減速度 {math}`a_{dec}` で残り距離 {math}`d` を使い切る速度を、運動方程式から計算します。

```{math}
v^2-v_{end}^2=2a_{dec}d
```

終端速度を {math}`v_{end}=0` とすると、目標速度は次になります。

```{math}
v_{cmd}=\min\left(v_{max},\sqrt{2a_{dec}d}\right)
```

`path.follow.stop.velocity_ff.max_deceleration` を小さくすると早い位置から緩やかに減速し、大きくすると終点近くまで高速を保ちます。この方式は現在速度を式に使わないため、速度計測のノイズに強い一方、指令どおりの減速度が実機で出ない場合は停止位置に誤差が残ります。

## bang_bang

現行実装は、切替距離内に入った時刻を保持し、一定速度保持と P 制御の2段階で停止します。加速度を積分する方式ではありません。

初めて {math}`d_g<d_s` になった時点を {math}`t_0` とし、{math}`T_h` を `hold_duration_sec`、{math}`v_h` を `hold_speed`、{math}`k_p` を `p_gain` とします。

```{math}
v_{cmd}=\begin{cases}
v_{max} & (\text{未切替かつ }d_g\ge d_s)\\
\min(v_{max},v_h) & (t-t_0<T_h)\\
\operatorname{clamp}(k_p\max(0,d_g-d_{goal}),0,\min(v_{max},v_h)) & (t-t_0\ge T_h)
\end{cases}
```

一度切り替わると、距離が再び `switching_distance` 以上になっても保持・P 制御を継続します。経過時間には `steady_clock` を使うため、Gazebo のシミュレーション時刻ではなく実時間です。新しい `FollowPath` goal の開始時に履歴をリセットします。

P 制御段階では `simple_pure_pursuit` が並進方向を現在位置から終点へ向け直します。終点を通り過ぎた場合も終点側へ戻る指令になります。一定速度保持中には action の停止完了判定を行わず、P 制御へ移った後に下記の4条件で判定します。角速度は引き続き pure pursuit 側で計算します。

`pseudo_acceleration_ff` は削除済みです。この mode を指定すると初期化に失敗します。また、旧 `bang_bang.max_acceleration` / `max_deceleration` は現行制御で使用しません。古い example YAML にこれらのキーが残っている場合も、以下の現行キーに置き換えて調整してください。

(stop-goal-judgement)=
## 停止完了判定

速度指令が小さくなっただけでは停止完了にしません。次の4条件をすべて満たしたときに `FollowPath` action を success にし、`/cmd_vel` を 0 にします。

```{math}
d_g<d_{goal}
```

```{math}
|\operatorname{wrap}(\theta_g-\theta_r)|<\theta_{goal}
```

```{math}
|v_k|<v_{goal}
```

```{math}
|\omega_k|<\omega_{goal}
```

角度しきい値の ROS parameter は degree、内部計算は radian です。速度判定には `/odom` の `twist` を使います。

## Parameter

| parameter | default | 単位 | 使用 mode | 説明 |
| --- | ---: | --- | --- | --- |
| `path.follow.stop.mode` | `distance_interpolation` | ― | 全体 | 停止方式を選択 |
| `path.follow.stop.distance_interpolation.gain` | `1.0` | 1/s | `distance_interpolation` | 終点距離に掛ける停止 gain {math}`k_s` |
| `path.follow.stop.distance_interpolation.switching_distance` | `0.1` | m | `distance_interpolation` | 停止制御への切替距離 {math}`d_s` |
| `path.follow.stop.velocity_ff.switching_distance` | `1.0` | m | `velocity_ff` | 停止制御への切替距離 {math}`d_s` |
| `path.follow.stop.velocity_ff.max_deceleration` | `1.0` | m/s² | `velocity_ff` | 最大減速度の大きさ {math}`a_{dec}` |
| `path.follow.stop.bang_bang.switching_distance` | `1.0` | m | `bang_bang` | 停止制御への切替距離 {math}`d_s` |
| `path.follow.goal.dist_threshold` | `0.01` | m | 全体 | 位置の停止完了しきい値 {math}`d_{goal}` |
| `path.follow.goal.yaw_threshold_deg` | `1.0` | deg | 全体 | yaw の停止完了しきい値 {math}`\theta_{goal}` |
| `path.follow.goal.linear_velocity_threshold` | `0.05` | m/s | 全体 | 並進速度の停止完了しきい値 {math}`v_{goal}` |
| `path.follow.goal.angular_velocity_threshold` | `0.05` | rad/s | 全体 | 角速度の停止完了しきい値 {math}`\omega_{goal}` |
| `path.follow.velocity.max_linear` | `1.0` | m/s | 全体 | 出力速度上限 {math}`v_{max}` |
| `path.follow.stop.bang_bang.hold_duration_sec` | `0.5` | s | `bang_bang` | 一定速度の保持時間 |
| `path.follow.stop.bang_bang.hold_speed` | `0.5` | m/s | `bang_bang` | 保持速度・P 制御の速度上限 |
| `path.follow.stop.bang_bang.p_gain` | `1.0` | 1/s | `bang_bang` | 残り制動距離に掛ける P gain |
| `control_period_ms` | `10` | ms | 全体 | pure pursuit の制御周期 |

切替距離、速度 FF の減速度、保持速度、P gain には 0 より大きい有限値が必要です。距離補間 gain、保持時間、各完了しきい値は 0 以上の有限値、制御周期は正の値にします。未選択方式の設定も検証されます。

## 設定例

`control/config.yaml` または `control/<profile>/config.yaml` に記述します。

```yaml
simple_pure_pursuit:
  ros__parameters:
    path:
      follow:
        stop:
          mode: bang_bang
          bang_bang:
            switching_distance: 1.0
            hold_duration_sec: 0.5
            hold_speed: 0.5
            p_gain: 2.0
        goal:
          dist_threshold: 0.01
          yaw_threshold_deg: 1.0
          linear_velocity_threshold: 0.05
          angular_velocity_threshold: 0.05
    control_period_ms: 10
```

これは `example/test/config/control/real/config.yaml` の停止設定です。sample の既定方式は `distance_interpolation` です。test 実機設定の `max_linear` は `2.0 m/s`、モータ上限は `1000 rad/s` で、sample の `1.0 m/s`、`200 rad/s` とは異なります。表の default はノードの宣言値であり、example ごとの調整値ではありません。
