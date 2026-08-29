# State / BehaviorTree

| ノード | 実行ファイル / plugin | 説明 |
| --- | --- | --- |
| `state_node` | `state_node` / `state::StateNode` | BehaviorTree XML を 10 ms 周期で tick し、状態遷移と action 実行を管理します。 |
| `groot` | `common_tool/Groot/build/Groot` | BehaviorTree の monitor GUI です。`enable_groot` が true のとき起動します。 |

`state_node` は `tree_path` で指定した XML を読みます。
