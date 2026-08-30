# WaitStart

## 役割

`WaitStart` は `/start` topic の `std_msgs/msg/Bool` が true になるまで待つ BehaviorTree action node です。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| subscribe | `/start` | `std_msgs/msg/Bool` |

## 状態

内部フラグを {math}`b` とします。

```{math}
b\in\{\mathrm{false},\mathrm{true}\}
```

`onStart()` では必ず false に戻します。

```{math}
b\leftarrow\mathrm{false}
```

topic callback は true だけを記録します。

```{math}
\mathrm{msg.data}=\mathrm{true}\Rightarrow b\leftarrow\mathrm{true}
```

`onRunning()` の返り値は、

```{math}
b=\mathrm{true}\Rightarrow\mathrm{SUCCESS}
```

```{math}
b=\mathrm{false}\Rightarrow\mathrm{RUNNING}
```

です。false message は停止命令ではなく、単に無視されます。

## 設定ファイル

この node は `example/sample/config/tree/main.xml` の `Action ID="WaitStart"` として使えます。sample の `MainTree` には現在 `WaitStart` は配置されていませんが、`TreeNodesModel` には登録されています。

```xml
<Action ID="WaitStart"/>
```

開始待ちを入れる場合は、`Sequence` の先頭に置きます。

```xml
<Sequence name="follow_all_paths">
    <Action ID="WaitStart"/>
    <Action ID="FollowPath" path_index="0"/>
</Sequence>
```

topic 名 `/start` は C++ 実装に固定されています。設定ファイルからは remap していないため、変更する場合は launch の remapping 追加または実装変更が必要です。
