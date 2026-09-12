# stop

## 役割

`stop` は `simple_pure_pursuit` の終点接近時に並進目標速度を生成し、停止完了を判定する `StopController` です。独立した ROS node ではなく、`rogi_control/stop/stop.hpp` を include して使用します。

停止方式は `path.follow.stop.mode` で選択します。

| mode | 概要 | 主に使う情報 |
| --- | --- | --- |
| `distance_interpolation` | 終点距離による速度補間 | 終点距離 |
| `velocity_ff` | 制動距離から速度を先に決める速度 FF | 終点距離、最大減速度 |
| `bang_bang` | 最大加速度と最大減速度を切り替える | 終点距離、現在速度 |
| `pseudo_acceleration_ff` | 速度入力の変化から擬似的な加速度 FF を作る | 終点距離、現在速度、前回入力速度 |

既定値は `distance_interpolation` です。mode は起動時に読み込まれ、存在しない文字列を指定すると node の初期化を失敗させます。

## 記号

以降では次の記号を使います。

| 記号 | 意味 | 対応 parameter |
| --- | --- | --- |
| {math}`d_g` | 現在位置から経路終点までの距離 | ― |
| {math}`d_{goal}` | 停止完了とみなす位置許容差 | `path.follow.goal.dist_threshold` |
| {math}`d` | 速度計算に使う残り制動距離 | ― |
| {math}`v_{max}` | 並進速度上限 | `path.follow.velocity.max_linear` |
| {math}`v_k` | odometry から得た現在並進速度 | ― |
| {math}`v_{cmd,k}` | 今回出力する並進目標速度 | ― |
| {math}`\Delta t` | 制御周期 | `control_period_ms / 1000` |
| {math}`a_{max}` | 最大加速度 | `path.follow.stop.max_acceleration` |
| {math}`a_{dec}` | 最大減速度の大きさ | `path.follow.stop.max_deceleration` |

`distance_interpolation` 以外の方式では、位置許容差の内側で速度入力が 0 になるよう、次の残り制動距離を使います。

```{math}
d=\max(0,d_g-d_{goal})
```

現在並進速度は `/odom` の body velocity から計算します。

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

{math}`d_s` は `path.follow.threshold.stop`、{math}`k_s` は `path.follow.gain.stop` です。現在速度をフィードバックしないため単純ですが、実機の応答遅れや慣性によって停止位置が変わります。

## velocity_ff

一定減速度 {math}`a_{dec}` で残り距離 {math}`d` を使い切る速度を、運動方程式から計算します。

```{math}
v^2-v_{end}^2=2a_{dec}d
```

終端速度を {math}`v_{end}=0` とすると、目標速度は次になります。

```{math}
v_{cmd}=\min\left(v_{max},\sqrt{2a_{dec}d}\right)
```

`path.follow.stop.max_deceleration` を小さくすると早い位置から緩やかに減速し、大きくすると終点近くまで高速を保ちます。この方式は現在速度を式に使わないため、速度計測のノイズに強い一方、指令どおりの減速度が実機で出ない場合は停止位置に誤差が残ります。

## bang_bang

現在速度から必要制動距離を計算します。

```{math}
d_{stop}=\frac{v_k^2}{2a_{dec}}
```

残り距離が必要制動距離より長ければ最大加速し、短ければ最大減速します。

```{math}
a_{cmd}=\begin{cases}
-a_{dec} & (d\le d_{stop})\\
a_{max} & (d>d_{stop})
\end{cases}
```

```{math}
v_{cmd,k}=\operatorname{clamp}
\left(v_k+a_{cmd}\Delta t,0,v_{max}\right)
```

現在速度と制動距離を直接比較するため、高速域から停止を開始する位置を決めやすい方式です。一方、切替境界付近では odometry の速度ノイズや制御周期の影響で加速と減速が切り替わりやすくなります。

## pseudo_acceleration_ff

まず `velocity_ff` と同じ式で入力速度 {math}`v_{in,k}` を作ります。

```{math}
v_{in,k}=\min\left(v_{max},\sqrt{2a_{dec}d}\right)
```

入力速度の差分を、入力側の擬似加速度とします。

```{math}
a_{in,k}=\frac{v_{in,k}-v_{in,k-1}}{\Delta t}
```

現在速度と入力速度の差を時定数 {math}`\tau` で加速度へ変換し、加速度 FF を加えます。

```{math}
a_{out,k}=\operatorname{clamp}\left(
\frac{v_{in,k}-v_k}{\tau}+K_{ff}a_{in,k},
-a_{dec},a_{max}
\right)
```

出力速度は現在速度から 1 step 積分します。

```{math}
v_{cmd,k}=\operatorname{clamp}\left(
v_k+a_{out,k}\Delta t,0,v_{max}
\right)
```

{math}`\tau` は `path.follow.stop.velocity_time_constant`、{math}`K_{ff}` は `path.follow.stop.acceleration_ff_gain` です。新しい `FollowPath` goal の開始時に入力速度履歴をリセットし、最初の step だけ {math}`a_{in,0}=0` とします。

{math}`\tau` を小さくすると入力速度への追従が速くなりますが、加速度上限へ張り付きやすくなります。{math}`K_{ff}` を大きくすると入力速度変化を先取りできますが、距離推定の揺れも増幅しやすくなります。

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
| `path.follow.gain.stop` | `1.0` | 1/s | `distance_interpolation` | 終点距離に掛ける停止 gain {math}`k_s` |
| `path.follow.threshold.stop` | `0.1` | m | `distance_interpolation` | 減速開始距離 {math}`d_s` |
| `path.follow.stop.max_acceleration` | `1.0` | m/s² | `bang_bang`, `pseudo_acceleration_ff` | 加速側の clamp 上限 {math}`a_{max}` |
| `path.follow.stop.max_deceleration` | `1.0` | m/s² | `velocity_ff`, `bang_bang`, `pseudo_acceleration_ff` | 減速側の大きさ {math}`a_{dec}` |
| `path.follow.stop.velocity_time_constant` | `0.2` | s | `pseudo_acceleration_ff` | 速度偏差を加速度へ変換する時定数 {math}`\tau` |
| `path.follow.stop.acceleration_ff_gain` | `1.0` | ― | `pseudo_acceleration_ff` | 擬似入力加速度の FF gain {math}`K_{ff}` |
| `path.follow.goal.dist_threshold` | `0.01` | m | 全体 | 位置の停止完了しきい値 {math}`d_{goal}` |
| `path.follow.goal.yaw_threshold_deg` | `1.0` | deg | 全体 | yaw の停止完了しきい値 {math}`\theta_{goal}` |
| `path.follow.goal.linear_velocity_threshold` | `0.05` | m/s | 全体 | 並進速度の停止完了しきい値 {math}`v_{goal}` |
| `path.follow.goal.angular_velocity_threshold` | `0.05` | rad/s | 全体 | 角速度の停止完了しきい値 {math}`\omega_{goal}` |
| `path.follow.velocity.max_linear` | `1.0` | m/s | 全体 | 出力速度上限 {math}`v_{max}` |
| `control_period_ms` | `10` | ms | `bang_bang`, `pseudo_acceleration_ff` | 差分と積分に使う周期 {math}`\Delta t` |

加速度、減速度、時定数には 0 より大きい有限値、FF gain と各完了しきい値には 0 以上の有限値が必要です。

## 設定例

```yaml
simple_pure_pursuit:
  ros__parameters:
    # 使用する停止ロジックを1つだけ有効にする
    # path.follow.stop.mode: distance_interpolation
    # path.follow.stop.mode: velocity_ff
    # path.follow.stop.mode: bang_bang
    path.follow.stop.mode: pseudo_acceleration_ff
    path.follow.stop.max_acceleration: 1.0
    path.follow.stop.max_deceleration: 1.0
    path.follow.stop.velocity_time_constant: 0.2
    path.follow.stop.acceleration_ff_gain: 1.0
    path.follow.goal.dist_threshold: 0.01
    path.follow.goal.yaw_threshold_deg: 1.0
    path.follow.goal.linear_velocity_threshold: 0.05
    path.follow.goal.angular_velocity_threshold: 0.05
    control_period_ms: 10
```

実機調整では、まず低速で `velocity_ff` の `max_deceleration` を実際の制動性能に合わせます。その後 `bang_bang` または `pseudo_acceleration_ff` に切り替え、`max_acceleration`、{math}`\tau`、{math}`K_{ff}` の順に調整します。
