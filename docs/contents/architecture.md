# rogi_nav アーキテクチャ

![rogi_nav architecture](../_static/architecture.svg)

現在の実装と `example/sample` の設定を基にした概要図です。実線は主な実行時のデータフロー、破線は経路ファイルの読み込みを表します。図は直接編集できる SVG で、ブラウザのライト／ダークテーマと「視差効果を減らす」設定に対応しています。接続線のアニメーションは方向を示す装飾であり、実際の通信状態や周期を示すものではありません。

## 起動と行動制御

[`rogi_nav.launch.py`](https://github.com/KeioRoboticsAssociation/rogi_nav/blob/main/rogi_launch/launch/rogi_nav.launch.py) が example の設定を読み込み、各コンポーネントを起動します。`real.yaml` / `sim.yaml` で実行環境と有効なノードを選び、`initial_pose.yaml` で初期位置を指定します。図のカードは機能単位であり、プロセスやコンテナの境界ではありません。

[`state_node`](https://github.com/KeioRoboticsAssociation/rogi_nav/blob/main/rogi_state/state/src/state_node.cpp) は BehaviorTree.CPP v3 で設定された `state_node.ros__parameters.tree_path`（既定 `tree/main.xml`）を実行します。`WaitStart` は `/start` を待ち、`FollowPath` は `/follow_path` action に `path_index` を渡します。結果・キャンセルの接続は図では省略しています。

[`simple_pure_pursuit`](https://github.com/KeioRoboticsAssociation/rogi_nav/blob/main/rogi_control/simple_pure_pursuit/src/simple_pure_pursuit_node.cpp) は事前に作成した経路 CSV を読み込み、指定された経路と `/localization_pose` から `/cmd_vel` を生成します。`/robot_pose` の Pose2D 入力にも対応しています。図の経路 CSV はオンラインの経路計画ノードではありません。

## 地図・自己位置推定

[`map_loader` / `map_converter`](https://github.com/KeioRoboticsAssociation/rogi_nav/blob/main/rogi_launch/launch/components/map.launch.py) は直線・円の CSV を読み込み、形状地図 `/raw_map` と占有格子地図 `/map` を配信します。

[`localization.launch.py`](https://github.com/KeioRoboticsAssociation/rogi_nav/blob/main/rogi_launch/launch/components/localization.launch.py) は `localization_method` に応じて以下の一方を起動します。

| 手法 | 主な入力 | 出力 |
| --- | --- | --- |
| `ransac` | `scan_merger` → `line_detector` → `/line_segments`、`/raw_map`、`/odom` | `/localization_pose`、TF `map → odom` |
| `emcl2` | LaserScan、`/map`、オドメトリの TF | `/localization_pose`、TF `map → odom` |

[`sensing.launch.py`](https://github.com/KeioRoboticsAssociation/rogi_nav/blob/main/rogi_launch/launch/components/sensing.launch.py) の PicoScan・scan merger・line detector は RANSAC 選択時に起動します。EMCL2 は line detector を経由しません。シミュレーションでの scan 入力は [`scan_frame_normalizer`](https://github.com/KeioRoboticsAssociation/rogi_nav/blob/main/rogi_simulator/scripts/scan_frame_normalizer.py) が `/scan_for_localization` に出力します。実機で EMCL2 を利用する場合は、別途 LaserScan の供給元とトピック設定が必要です。図では EMCL2 への scan 接続と各ノードの TF 接続を文字で補足しています。

トピック名は launch の remap と example の設定を反映した代表例です。ノードを単体起動した場合や設定を変更した場合は異なることがあります。

## 実機とシミュレーション

| プロファイル | 指令 | フィードバック |
| --- | --- | --- |
| 実機 | `/cmd_vel` → `cmd_vel_to_dcmotor` → `/rogidrive_cmd` → 実機インターフェース | PicoScan の scan、`/rogidrive_status` → `wheel_odometry` → `/odom`・TF |
| Gazebo | `/cmd_vel` → `ros_gz_bridge` → シミュレートされたロボット | scan、`/odom_raw` → `odom_drift_simulator` → `/odom`、`odom_tf_broadcaster` による TF |

RANSAC localizer のサービス `/localization/set_ransac_enabled` に `false` を送ると、現在の推定 pose から odometry だけで伝播する `odom_only` に切り替わります。`true` で再捕捉へ戻ります。`localization.method: odom` や開始時に原点をリセットする `relative_odometry` ノードは現在の実装にはありません。

実機インターフェースの `rs485_interface2` と `stm32_mavlink_udp` は外部パッケージです。図では launch が選択する接続先としてまとめています。

シミュレータのディレクトリ名は `rogi_simulator`、ROS パッケージ名は `gazebo_simulator` です。オドメトリのドリフト付与は設定で切り替えます。図の左端の矢印は選択された実行環境からのセンサーフィードバックをまとめたものです。

## 可視化

RViz2 と visualizer は地図・経路・自己位置を表示します。Groot Monitor は `state_node` の ZeroMQ 出力で Behavior Tree の状態を表示します。統合 Web 配信は RViz / Groot をブラウザのタブで表示します。これらは設定で有効化する観測用ツールです。

## 図の編集

編集対象は [`_static/architecture.svg`](../_static/architecture.svg) です。外部フォント・画像・JavaScript への依存はありません。変更後はブラウザで開き、文字のはみ出しと接続線を確認してください。

デザイン参考: [Grove-G1 のアーキテクチャ図](https://github.com/Adyansh04/grove-g1/blob/main/docs/media/architecture.svg)。色分け・角丸カード・流れる接続線の表現を参考に、rogi_nav の実装に合わせて作成しています。

BT からは地図エリアと RANSAC 補正モードも変更できます。[](nodes/state/environment-actions.md) を参照してください。停止時には `/odom` の並進・角速度も判定に使います。RViz の状態 HUD と記録・再生は [](nodes/visualization.md) にまとめています。
