# FollowPath / FollowPathAction

## 役割

`FollowPath` は `simple_pure_pursuit` の `follow_path` action server を呼ぶ BehaviorTree action node です。XML では `path_index` input port に経路番号を渡します。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| input port | `path_index` | 実行する経路 index |
| action client | `follow_path` | `rogi_msgs/action/FollowPath` |

## 状態遷移

内部状態を、

```{math}
q\in\{\mathrm{START},\mathrm{WAIT\_SERVER},\mathrm{WAIT\_GOAL},\mathrm{WAIT\_RESULT},\mathrm{DONE}\}
```

とみなせます。

`onStart()` では input port を読みます。

```{math}
i_p = B[\mathrm{path\_index}]
```

読み取りに失敗した場合は `FAILURE` です。成功した場合は action goal の送信準備だけ行い、`RUNNING` を返します。

## Goal 送信

server が未準備なら、

```{math}
\operatorname{ready}(\mathrm{follow\_path})=\mathrm{false}
```

なので `RUNNING` を返して待ちます。server が準備できたら goal を送ります。

```{math}
g=\{ \mathrm{path\_index}=i_p \}
```

goal handle が null の場合、server に reject されたため `FAILURE` です。

## Result 判定

result code を {math}`c`、result の success flag を {math}`b` とします。成功条件は次だけです。

```{math}
c=\mathrm{SUCCEEDED}\land b=\mathrm{true}
```

それ以外は `FAILURE` です。

```{math}
c\in\{\mathrm{ABORTED},\mathrm{CANCELED}\}\lor b=\mathrm{false}
\Rightarrow \mathrm{FAILURE}
```

## Halt

上位 node から halt された場合、goal handle が存在すれば cancel を送ります。

```{math}
h\ne\emptyset \Rightarrow \operatorname{cancel}(h)
```

これにより BehaviorTree 側の中断と pure pursuit 側の走行停止要求を対応させます。

## 設定ファイル

この node は `example/sample/config/tree/main.xml` 内の `Action ID="FollowPath"` または `Action ID="FollowPathAction"` で使います。

```xml
<Action ID="FollowPath" path_index="0"/>
```

`path_index` は `simple_pure_pursuit` の `input.csv.follow_path_files` の index に対応します。

```{math}
\mathrm{path\_index}=i \Rightarrow P_i=\mathrm{follow\_path\_files}[i]
```

sample launch は `path/trajectory/{0..11}.csv` を 12 本登録します。そのため XML 側で `path_index="11"` までは参照できます。存在しない index や空 CSV を指定すると、pure pursuit 側で action goal が reject され、この BT node は `FAILURE` になります。

`TreeNodesModel` には Groot 表示用に input port も定義します。

```xml
<Action ID="FollowPath">
    <input_port name="path_index"/>
</Action>
```
