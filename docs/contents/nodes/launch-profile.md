# Launch profile

| profile | 主な用途 | 特徴 |
| --- | --- | --- |
| `real` | 実機 | Gazebo と Web を無効化し、picoScan、wheel odometry、MAVLink/RS485、DC motor command 変換を有効化します。 |
| `sim` | Gazebo シミュレーション | Gazebo、RViz、Web 表示、地図、scan merger、line detector、自己位置推定、pure pursuit、state node を有効化します。 |

上表は sample の設定です。test / nhk_2027 の起動可否・world・制御値は各 example の YAML を確認してください。`config_profile` の既定値は `real` です。読込順と上書き規則は [](../setup/config-files.md) を参照してください。
