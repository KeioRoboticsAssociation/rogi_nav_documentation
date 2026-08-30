# State / BehaviorTree

| ノード | 実行ファイル / plugin | 説明 |
| --- | --- | --- |
| `state_node` | `state_node` / `state::StateNode` | BehaviorTree XML を 10 ms 周期で tick し、状態遷移と action 実行を管理します。 |
| `groot` | `common_tool/Groot/build/Groot` | BehaviorTree の monitor GUI です。`enable_groot` が true のとき起動します。 |

`state_node` は `tree_path` で指定した XML を読みます。

## `state_node`

`state_node` は BehaviorTree.CPP v3 を使ってロボットの高レベル動作を実行します。起動時に `tree_path` parameter の XML を読み、10 ms 周期で root node を tick します。root が `SUCCESS` または `FAILURE` になったら実行完了として timer を止めます。`RUNNING` の間だけ tick が継続します。

blackboard には ROS node shared pointer と `move_index` parameter が入ります。各 BT node はこの node pointer を使って ROS topic や action にアクセスします。Groot 用に `PublisherZMQ` も作られるため、`groot` を起動すると tree の tick 状態を GUI で監視できます。

登録される BT node は `FollowPath`、`FollowPathAction`、`WaitStart`、`ActionSelection` です。`FollowPath` と `FollowPathAction` は同じ C++ class で、XML 側の名前違いに対応するため両方登録されています。

## `FollowPath` / `FollowPathAction`

`FollowPath` は `simple_pure_pursuit` の `follow_path` action server を呼び出す stateful action node です。input port は `path_index` です。`onStart()` で `path_index` を読み、内部状態を初期化して `RUNNING` を返します。

`onRunning()` の最初の段階では action server の readiness を確認します。server がまだ無ければ warning を throttle しながら `RUNNING` を返し続けます。server が使えるようになったら `rogi_msgs/action/FollowPath` goal を非同期送信し、goal handle の future を待ちます。

goal が reject された場合は BT node は `FAILURE` になります。accept された場合は result future を取得し、以降の tick で完了を待ちます。result が `SUCCEEDED` かつ `result->success` が true なら BT node は `SUCCESS`、`ABORTED`、`CANCELED`、`success=false` は `FAILURE` です。tree の `Sequence` 内で使うと、1 本の経路が完了してから次の経路へ進みます。

`onHalted()` では goal handle が存在する場合に action cancel を送ります。上位の fallback や control node によって中断された場合でも、pure pursuit 側が走り続けないようにするためです。

## `WaitStart`

`WaitStart` は `/start` topic の `std_msgs/msg/Bool` を待つ stateful action node です。`onStart()` で受信フラグを false に戻し、`onRunning()` で true を受け取るまで `RUNNING` を返します。`/start` に true が届くと `SUCCESS` になります。false は無視されます。

この node を tree の先頭に置くと、launch 後に各ノードを立ち上げたまま、外部スイッチや operator UI から開始信号を入れるまで動作を止められます。

## `ActionSelection`

`ActionSelection` は input port `plan` に書かれた文字列を解釈し、子 node の中から指定された node を順番に tick する control node です。通常の `Sequence` より動的で、実行する子 node 名と、その前に blackboard に入れる値を plan 側から指定できます。

plan 文字列は `;` 区切りの step 列です。各 step は `node_name` または `node_name:key=value,key=value` の形です。値は `true/false`、整数、double として parse されます。`wtt_back`、`wtt_front`、`expand` は bool key として扱われ、`climb_vel`、`time`、`vx`、`vy`、`vtheta` は double key として扱われます。それ以外の数値は整数に近ければ int、そうでなければ double になります。

tick 開始時、まだ plan が parse されていなければ input port から `Plan` に変換します。現在 step に `set_values` があれば、子 node を tick する前に blackboard へ値を書き込みます。子 node は名前 `name()` または登録名 `registrationName()` が step の `node` と一致するものを探します。見つからなければ `FAILURE` です。

子 node が `RUNNING` の間は `ActionSelection` も `RUNNING` を返します。子 node が `FAILURE` なら全体も `FAILURE`、`SUCCESS` ならその子を halt して次の step に進みます。すべての step が成功すると `SUCCESS` です。`halt()` されると全 child を halt し、plan index と set 済みフラグを初期化します。

## sample tree

`example/sample/config/tree/main.xml` では `Sequence` の中に `FollowPath` を並べ、`path_index=0` から順番に経路を実行します。途中の `Delay` は待ち時間を入れるための BehaviorTree.CPP 標準 node です。経路を増減する場合は、pure pursuit の CSV 配列と XML の `path_index` を同時に揃えます。
