# 主要な設定ファイル

| ファイル | 役割 |
| --- | --- |
| `example/sample/config/real.yaml` | 実機向け profile。Gazebo を止め、picoScan、wheel odometry、MAVLink/RS485、制御系を有効化します。 |
| `example/sample/config/sim.yaml` | シミュレーション向け profile。Gazebo、可視化、Web 表示、自己位置推定、pure pursuit を有効化します。 |
| `example/sample/config/simulation/config.yaml` | Gazebo の model、world、sim time、odom drift などを設定します。 |
| `example/sample/config/map/config.yaml` | 地図 CSV と Gazebo 壁生成パラメータを設定します。 |
| `example/sample/config/sensing/config.yaml` | LiDAR、scan merger、RANSAC line detector の設定です。 |
| `example/sample/config/localization/*/config.yaml` | `emcl2` または `ransac_localizer` の自己位置推定パラメータです。 |
| `example/sample/config/tree/main.xml` | `state_node` が読む BehaviorTree です。 |
| `example/sample/config/path/trajectory/*.csv` | `simple_pure_pursuit` と `path_visualizer` が読む経路 CSV です。 |
