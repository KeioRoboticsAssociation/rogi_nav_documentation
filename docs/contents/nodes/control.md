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
