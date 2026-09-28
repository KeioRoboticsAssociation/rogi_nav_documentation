# 補助ツール

| コマンド | 内容 |
| --- | --- |
| `make groot` | ビルド済み Groot を起動します。 |
| `make trajectory-generator` | TrajectoryGenerator GUI を起動します。 |
| `make map-builder` | map_builder の npm 依存を入れて開発サーバを起動します。 |
| `make clean-common-tool` | `common_tool` 配下の生成物を削除します。 |

map_builder には Node.js 20.19+ または 22.12+ と npm が必要です。`make map-builder` は未取得なら checkout を準備してから起動します。

経路の実行用 CSV は `path/trajectory`、編集用データは `path/wayoints` に配置します。生成した経路の角度は rad にし、`initial_pose.yaml` の yaw [degree] と取り違えないようにします。

`make clean-common-tool` は build/install/log、Python 仮想環境、map_builder の node_modules / dist などを削除します。外部リポジトリのソースは残ります。再利用時は `make setup` などで生成物を再作成します。
