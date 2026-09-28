# 実装との対応

このドキュメントはローカルの rogi_nav `bc5bdcb`（2026-09-29 確認）のソース・launch・example YAML を基準にしています。外部リポジトリの機能は rogi_nav からの接続範囲を記載します。

| 反映項目 | 確認した実装 / 設定 |
| --- | --- |
| 停止方式3種、bang_bang の保持・P 制御、完了条件 | `rogi_control/stop/stop.hpp`、`simple_pure_pursuit_node.cpp` |
| test の角度先行到達、速度と停止設定 | `example/test/config/path/trajectory/{0,1}.csv`、`control/real/config.yaml` |
| 全輪共通の速度制限、rev/s 変換、yaw 反転 | `cmd_vel_to_dcmotor_node.cpp` |
| 累積エンコーダ差分、yaw 反転 | `wheel_odometry_node.cpp`、各 example の wheel odometry YAML |
| profile 別設定、tree 選択、初期姿勢 | `rogi_launch/launch/rogi_nav.launch.py` |
| 地図切替、補正モード切替、Gazebo 水平化 | `rogi_state/state/src/actions`、`map_loader.cpp` |
| RANSAC の長さ重み・直交条件・再捕捉状態 | `ransac_localizer.cpp` |
| 地図変換の円分割数、閉ループの壁面配置 | `map_converter.cpp`、`map_world_generator.py` |
| scan の設定受渡し・QoS | `sensing.launch.py`、`scan_merger.cpp`、`line_detector.cpp` |
| HUD、経路表示、rosbag 記録・再生 | `rogi_visualization`、`rosbag_*.launch.py` |
| ホスト・Docker 起動、共通ツール | `Makefile`、`docker/*.sh`、`common_tool/common_tool.repos` |

## 設定に残る旧記述

sample など一部の YAML に旧 `bang_bang.max_acceleration` / `max_deceleration` が残っていますが、現行コードは使いません。[](nodes/control/stop.md) の `hold_duration_sec`、`hold_speed`、`p_gain` を使用します。

sample の BT は経路 0〜11 を要求しますが、CSV は 0・1 のみです。[](nodes/state/follow-path-action.md) の説明に従い、実行対象と CSV を揃えます。

`localization.method: odom`、削除済み `pseudo_acceleration_ff`、旧 sample 専用 launch を使う説明は現行構成へ更新しました。

Makefile の `down` は `.PHONY` 宣言のみで停止処理がありません。起動端末の `Ctrl+C` で停止します。
