# State / BehaviorTree

状態管理系ノードは、BehaviorTree の tick、開始待ち、経路実行 action、動的な子 node 選択を担当します。

| ノード | 実行ファイル / plugin | 説明 |
| --- | --- | --- |
| `state_node` | `state_node` / `state::StateNode` | BehaviorTree XML を 10 ms 周期で tick し、状態遷移と action 実行を管理します。 |
| `groot` | `common_tool/Groot/build/Groot` | BehaviorTree の monitor GUI です。`enable_groot` が true のとき起動します。 |

```{toctree}
:maxdepth: 1

state/state-node
state/follow-path-action
state/wait-start
state/action-selection
```
