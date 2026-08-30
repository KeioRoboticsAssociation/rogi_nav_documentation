# Control

制御系ノードは、経路追従と body velocity から wheel command への変換を担当します。

| ノード | 実行ファイル / plugin | 説明 |
| --- | --- | --- |
| `simple_pure_pursuit` | `simple_pure_pursuit_node` / `simple_pure_pursuit::SimplePurePursuitNode` | 経路 CSV を読み込み、`FollowPath` action の goal に応じて `/cmd_vel` を生成します。 |
| `cmd_vel_to_dcmotor_node` | `cmd_vel_to_dcmotor_node` / `cmd_vel_to_dcmotor::CmdVelToDCMotorNode` | `geometry_msgs/msg/Twist` を Rogidrive の motor command に変換します。 |

```{toctree}
:maxdepth: 1

control/simple-pure-pursuit
control/cmd-vel-to-dcmotor
```
