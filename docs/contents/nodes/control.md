# Control

| ノード | 実行ファイル / plugin | 説明 |
| --- | --- | --- |
| `simple_pure_pursuit` | `simple_pure_pursuit_node` / `simple_pure_pursuit::SimplePurePursuitNode` | 経路 CSV を読み込み、`FollowPath` action の goal に応じて `/cmd_vel` を生成します。 |
| `cmd_vel_to_dcmotor_node` | `cmd_vel_to_dcmotor_node` / `cmd_vel_to_dcmotor::CmdVelToDCMotorNode` | `geometry_msgs/msg/Twist` を Rogidrive の motor command に変換します。 |

| ノード | 種別 | 名前 | 型 / 内容 |
| --- | --- | --- | --- |
| `simple_pure_pursuit` | action server | `follow_path` | `rogi_msgs/action/FollowPath` |
| `simple_pure_pursuit` | subscribe | `/localization_pose`, `/robot_pose` | 現在 pose |
| `simple_pure_pursuit` | publish | `/cmd_vel`, `/pure_pursuit_path`, `/distance_to_goal`, `/current_follow_path_index` | 速度指令、可視化、状態 |
| `cmd_vel_to_dcmotor_node` | subscribe | `/cmd_vel` | `geometry_msgs/msg/Twist` |
| `cmd_vel_to_dcmotor_node` | publish | `/rogidrive_cmd` | Rogidrive motor command |
| `cmd_vel_to_dcmotor_node` | parameter | `wheel_radius`, `center_to_wheel`, `motor_names` など | omni wheel と motor の変換条件 |

## `simple_pure_pursuit`

`simple_pure_pursuit` は CSV 経路を読み込み、`rogi_msgs/action/FollowPath` の goal で指定された経路 index を追従します。制御周期は 10 ms です。pose 入力は `pose_with_covariance_topic`、通常 `/localization_pose` の `PoseWithCovarianceStamped` が主で、互換用に `/robot_pose` の `Pose2D` も購読します。

経路 CSV は `input.csv.follow_path_files` に並べたファイルを起動時にすべて読みます。各行は `x,y,theta` で、数字、符号、小数点で始まらない行は header やコメントとして読み飛ばします。読み込んだ経路は `paths_[path_index]` として保持され、action goal の `path_index` が範囲外、または空の経路なら goal は reject されます。同時に複数 goal は受けず、実行中は busy として reject します。

action goal を受けると内部 state を `FOLLOW_PATH` にし、`/current_follow_path_index` に index を publish します。action 実行スレッドは 20 Hz で state を監視し、timer 側が goal 到達を検出して `IDLE` に戻したら success result を返します。cancel された場合は `IDLE` に戻し、index を `-1` に戻し、ゼロ速度を publish して canceled result にします。

追従アルゴリズムでは、まず現在 pose から最も近い経路点 `nearest_index` を全探索で探します。次に `nearest_index` 以降で、現在 pose からの距離が `lookahead_distance` 以上になる最初の点を `lookahead_index` にします。見つからない場合は終点を lookahead にします。

lookahead 点と nearest 点へのベクトルは、現在 yaw を使って robot 座標に変換されます。lookahead ベクトル `t_lookahead` と nearest ベクトル `t_nearest` の内積から、nearest 方向成分 `h` を求め、`t = t_lookahead - (1 - lateral_gain) * h` を制御目標方向にします。`lateral_gain` が大きいほど lookahead 点へ素直に向かい、小さいほど nearest 点方向の成分を抑えて横ずれ補正を強めます。

並進速度は目標方向 `t` を正規化し、`path.follow.velocity.max_linear` を掛けたものです。回転速度は `rotate_gain * normalizeAngle(target_theta - pose_theta)` で、通常は nearest 点の `theta`、lookahead が終点の場合は終点の `theta` を使います。`path.follow.velocity.max_angular` を超える場合は angular を clamp し、同時に `xy_scale_adjust` を掛けた比率で並進速度も落とします。大きく旋回が必要なときに並進しすぎないためです。

終点が近い場合は減速します。終点までの距離 `dist_to_end` が `stop_threshold` 未満なら、`max_vel * alpha + stop_gain * dist_to_end * (1 - alpha)` で目標速度を作ります。`alpha = dist_to_end / stop_threshold` なので、遠い側では max 速度に近く、終点では距離比例の停止制御に寄ります。

goal 判定は位置と姿勢の両方です。終点までの距離が `path.follow.goal.dist_threshold` 未満、かつ終点 yaw との差が `path.follow.goal.yaw_threshold_deg` 未満になると追従完了です。完了時は `/cmd_vel` をゼロにし、`/current_follow_path_index` を `-1` に戻します。毎周期、可視化用の `/pure_pursuit_path` と `/distance_to_goal` も publish します。

`path.follow.velocity.max_linear` と `path.follow.velocity.max_angular` は実行中に parameter update できます。値は double、有限、非負でなければ reject されます。経路の差し替えは起動時読み込みのため、CSV を変えた場合はノード再起動が必要です。

## `cmd_vel_to_dcmotor_node`

`cmd_vel_to_dcmotor_node` は ROS の body velocity `/cmd_vel` を Rogidrive の wheel 速度 command に変換します。入力は `geometry_msgs/msg/Twist` の `linear.x`, `linear.y`, `angular.z` で、出力は motor ごとの Rogidrive message です。publish 周期は `publish_period_sec`、既定は 20 ms です。

callback では最新の `/cmd_vel` と受信時刻だけを保存します。timer では `cmd_vel_timeout_sec` を超えて新しい command が来ない場合、`stop_on_timeout` が true なら各 motor に 1 回だけ速度 0 の command を送ります。timeout 中は古い command を繰り返しません。`disable_on_zero` が true の場合、速度絶対値が `zero_epsilon` 以下の motor は enable false 相当の command になります。

kinematics は wheel ごとに個別計算します。wheel の位置は `center_to_wheel` と `wheel_position_angles_deg` から `(wheel_x, wheel_y)`、駆動方向は `wheel_drive_angles_deg` から単位ベクトル `(drive_x, drive_y)` を作ります。robot の速度場は wheel 位置で `(linear_x - angular_z * wheel_y, linear_y + angular_z * wheel_x)` です。この速度を wheel 駆動方向に射影した値が接地点速度です。

接地点速度を `wheel_radius` で割ると omni wheel の角速度になり、`motor_to_omni_reduction_ratio` と `motor_signs[i]` を掛けて motor 角速度にします。最後に `max_motor_speed_rad_s` で clamp し、Rogidrive の velocity control mode として publish します。実装では物理 wheel 配置の yaw 符号に合わせるため、ROS の正の `angular.z` を内部で一度反転しています。linear 軸は反転しません。

`motor_names`、`wheel_position_angles_deg`、`wheel_drive_angles_deg`、`motor_signs` は同じ長さである必要があります。長さが一致しない場合は fatal error で起動に失敗します。wheel 配置を変更したときは、このノードと `wheel_odometry` の wheel parameter を必ず同じ幾何で揃えます。
