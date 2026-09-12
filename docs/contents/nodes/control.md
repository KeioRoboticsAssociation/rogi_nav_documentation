# Control

制御系コンポーネントは、経路追従、終点停止、body velocity から wheel command への変換を担当します。

| コンポーネント | 実行ファイル / plugin / class | 説明 |
| --- | --- | --- |
| `simple_pure_pursuit` | `simple_pure_pursuit_node` / `simple_pure_pursuit::SimplePurePursuitNode` | 経路 CSV を読み込み、`FollowPath` action の goal に応じて `/cmd_vel` を生成します。 |
| `stop` | `rogi_control::StopController` | `simple_pure_pursuit` に組み込まれ、終点付近の減速指令と停止完了判定を行います。 |
| `cmd_vel_to_dcmotor_node` | `cmd_vel_to_dcmotor_node` / `cmd_vel_to_dcmotor::CmdVelToDCMotorNode` | `geometry_msgs/msg/Twist` を Rogidrive の motor command に変換します。 |

```{toctree}
:maxdepth: 1

control/simple-pure-pursuit
control/stop
control/cmd-vel-to-dcmotor
```
