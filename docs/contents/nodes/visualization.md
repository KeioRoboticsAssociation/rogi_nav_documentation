# 可視化・記録と再生

## RViz と経路表示

`visualization/config.yaml` の `visualization.rviz_config` で RViz 設定を選びます。統合 launch では `launch.components.visualization` の各 `enabled` で起動を制御します。

| ノード / plugin | 入力 | 表示・出力 |
| --- | --- | --- |
| `line_segments_visualizer` | `line_segments` (`rogi_msgs/msg/LineSegmentArray`) | `line_segments_marker` (`visualization_msgs/msg/Marker`) |
| `path_visualizer` | 経路 CSV、`/current_follow_path_index` (`std_msgs/msg/Int32`) | `/nav_msg_path` (`nav_msgs/msg/Path`) |
| `rogi_rviz_plugin/NavigationStatusDisplay` | 真値 pose、推定 pose、cmd_vel、RANSAC 状態 | RViz の3Dビュー上の HUD |

`path_visualizer` は経路 index を受信したときだけ対応 CSV を表示します。負の index、未収録・空の CSV では空の Path を送って表示を消します。index と Path は `transient_local + reliable` で、後から接続した RViz にも最新値を渡します。CSV の yaw は rad です。

HUD は `/localization/ground_truth_pose` (`PoseStamped`)、`/localization_pose` (`PoseWithCovarianceStamped`)、`/cmd_vel` (`Twist`)、`/localization/ransac_state` (`String`) を購読します。x・y・theta の推定誤差、vx・vy・wz、RANSAC の捕捉・追跡・fallback・odom_only 状態を表示します。真値はシミュレータ側が供給します。

Groot Monitor は BT の ZeroMQ 出力を表示します。統合 Web 表示は RViz と Groot のタブを提供し、`launch.components.web.rogi_web.enabled` で起動します。

## rosbag 記録

全 topic を MCAP 形式で保存します。`rogi_nav.launch.py` に `record_all:=true record_output_dir:=<dir>` を渡すと、
記録を先に開始してから各 component を 1 秒遅らせて起動します（`make <example>` はこの形で実行ごとの
`output/<example>-<mode>-<日時>/` に記録します）。単体でも同じ引数で起動できます。

```bash
ros2 launch rogi_launch rosbag_record_all.launch.py \
  record_all:=true record_output_dir:="$HOME/rogi_nav_ws/src/rogi_nav/output/manual"
```

| 引数 | 既定値 / 内容 |
| --- | --- |
| `record_all` | `false`。`true` / `1` / `yes` で記録する |
| `record_output_dir` | 必須（記録時に空ならエラー） |
| `record_bag_name` | `rosbag`。`<record_output_dir>/<record_bag_name>` に保存。既存なら記録できないので出力先を分ける |
| `record_storage_id` | `mcap`。空なら ROS の既定形式 |

## rosbag 再生

```bash
ros2 launch rogi_launch rosbag_play.launch.py \
  rosbag_dir:="$HOME/rogi_nav_ws/src/rogi_nav/output" \
  bag:=latest rate:=1.0 start_paused:=true
```

`bag` は `latest`、更新日時が新しい順の index（0始まり）、bag ディレクトリ名、絶対パスで指定します。`loop:=true` で繰り返します。再生時は `--clock` を付け、同時に起動する RViz は `use_sim_time=true` にします。`rosbag_dir` の既定は `<rogi_nav>/output`（なければ `<rogi_nav>/rosbag`、`/rosbag`）で、配下を再帰的に探します。`rviz_config` で表示設定を変更できます。空（既定）の場合は、選択した bag と同じ実行ディレクトリに保存された `example/<example>/config/visualization/rviz/*.rviz` を使い、見つからなければ RViz の既定表示です。

停止時の SVG グラフ出力は rosbag と独立した機能です。[](control/simple-pure-pursuit.md) を参照してください。
