# state_node

## 役割

`state_node` は BehaviorTree XML を読み込み、10 ms 周期で root node を tick します。root が終端状態になったら timer を停止します。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| parameter | `tree_path` | 読み込む BehaviorTree XML |
| parameter | `move_index` | blackboard 初期値 |
| ZMQ | Groot monitor | `PublisherZMQ` |

## Tick model

tick 周期を {math}`T=10\mathrm{ms}` とします。時刻 {math}`t_k=kT` ごとに root を tick します。

```{math}
s_k=\operatorname{tickRoot}(\mathcal{T},t_k)
```

状態 {math}`s_k` は BehaviorTree.CPP の、

```{math}
s_k\in\{\mathrm{IDLE},\mathrm{RUNNING},\mathrm{SUCCESS},\mathrm{FAILURE}\}
```

です。実行継続条件は、

```{math}
s_k=\mathrm{RUNNING}
```

です。終端条件は、

```{math}
s_k\in\{\mathrm{SUCCESS},\mathrm{FAILURE}\}
```

で、このとき `finished_=true` として timer を cancel します。

## Blackboard

blackboard には ROS node pointer と `move_index` を入れます。

```{math}
B[\mathrm{node}]=n_{ros},\qquad B[\mathrm{move\_index}]=m
```

各 custom BT node は {math}`B[\mathrm{node}]` を使って ROS topic や action client を作ります。

## 登録 node

起動時に次を BehaviorTreeFactory へ登録します。

| 登録名 | C++ class | 用途 |
| --- | --- | --- |
| `FollowPath` | `FollowPathAction` | pure pursuit action の呼び出し |
| `FollowPathAction` | `FollowPathAction` | 同上 |
| `WaitStart` | `ReceiveStartSignal` | `/start=true` 待ち |
| `ActionSelection` | `ActionSelection` | plan 文字列による子 node 選択 |
| `SetLocalizationMode` | `SetLocalizationModeAction` | RANSAC 補正の有効・無効を切替 |
| `SetMapArea` | `SetMapAreaAction` | ground / level_1 地図を切替 |
| `LevelRobot` | `LevelRobotAction` | Gazebo モデルの roll / pitch を 0 にして高さを指定 |

## 設定ファイル

`state_node` は `state/config.yaml`（または profile 別セクション）の `state_node.ros__parameters.tree_path` を読みます。既定値は `tree/main.xml` です。`rogi_nav.launch.py` は `config_dir` 基準で相対 path を解決し、`tree_path` parameter として渡します。test は `tree/odom_only.xml` を選択しています。

```{math}
P_{\mathrm{tree}}=\operatorname{join}(D_{\mathrm{config}},\mathrm{tree\_path})
```

profile 側の起動 key は次です。

```yaml
launch:
  components:
    state:
      state_node:
        enabled: true
      groot:
        enabled: false
```

`move_index` は `state_node.ros__parameters.move_index` から `state.launch.py` へ渡されます。default は `0` です。地図・自己位置推定・Gazebo の切替は [](environment-actions.md) を参照してください。

Groot を使う場合は profile の `launch` 直下に次の optional key を置けます。

| key | default | 用途 |
| --- | --- | --- |
| `groot_address` | `localhost` | Groot monitor 接続先 |
| `groot_publisher_port` | `1666` | BT publisher port |
| `groot_server_port` | `1667` | BT server port |

`groot_executable` は `state.launch.py` が `ROGI_NAV_GROOT_EXECUTABLE` または `common_tool/Groot/build/Groot` から探します。
