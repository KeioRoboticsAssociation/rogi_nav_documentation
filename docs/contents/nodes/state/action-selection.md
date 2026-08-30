# ActionSelection

## 役割

`ActionSelection` は input port `plan` に書かれた文字列を parse し、子 node を指定順に tick する control node です。各 step の前に blackboard 値を設定できます。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| input port | `plan` | `;` 区切りの実行 plan |
| children | 任意の BT child node | plan の node 名に一致するものを tick |

## Plan grammar

plan は step の列です。

```{math}
P=[s_0,s_1,\dots,s_{N-1}]
```

文字列では `;` で区切ります。

```text
node_a:key=value,key=value; node_b; node_c:x=1
```

各 step は、

```{math}
s_k=(n_k,\{(key,value)\})
```

です。`:` より左が node 名、右が blackboard に書く key/value 集合です。

## 型変換

値文字列 {math}`v` は次の順で型変換されます。

```{math}
v\in\{\mathrm{true},\mathrm{false}\}\Rightarrow bool
```

bool key は数値でも bool に寄せます。

```{math}
key\in K_b=\{\mathrm{wtt\_back},\mathrm{wtt\_front},\mathrm{expand}\}
\Rightarrow value=(v\ne0)
```

double key は double です。

```{math}
key\in K_d=\{\mathrm{climb\_vel},\mathrm{time},\mathrm{vx},\mathrm{vy},\mathrm{vtheta}\}
\Rightarrow value\in\mathbb{R}
```

それ以外の数値は、整数に十分近ければ int、そうでなければ double です。

```{math}
|v-\operatorname{round}(v)|<10^{-6}\Rightarrow int
```

## Tick algorithm

現在の plan index を {math}`k` とします。初回 tick で plan を parse し、{math}`k=0` にします。step {math}`s_k` の set 値は、子 node を tick する前に blackboard へ書きます。

```{math}
B[key]\leftarrow value
```

子 node は、名前または登録名が一致するものを探します。

```{math}
c_k=\operatorname{findChild}(n_k)
```

見つからない場合は `FAILURE` です。

子 node の tick 結果を {math}`r_k` とすると、返り値は次です。

```{math}
r_k=\mathrm{RUNNING}\Rightarrow\mathrm{RUNNING}
```

```{math}
r_k=\mathrm{FAILURE}\Rightarrow\mathrm{FAILURE}
```

```{math}
r_k=\mathrm{SUCCESS}\Rightarrow k\leftarrow k+1
```

全 step が成功したら、

```{math}
k=N\Rightarrow\mathrm{SUCCESS}
```

です。halt された場合は全 child を halt し、{math}`k=0` に戻します。

## 設定ファイル

この node は `example/sample/config/tree/main.xml` の `Control ID="ActionSelection"` として使えます。sample の `MainTree` では現在使っていませんが、`TreeNodesModel` には登録されています。

```xml
<Control ID="ActionSelection">
    <input_port name="plan"/>
</Control>
```

XML で使う場合は、children と plan の node 名を一致させます。

```xml
<ActionSelection plan="FollowPath:path_index=0; FollowPath:path_index=1">
    <Action ID="FollowPath" path_index="{path_index}"/>
</ActionSelection>
```

plan の各 step は次の形です。

```text
node_name:key=value,key=value
```

`key=value` は tick 前に blackboard へ入ります。

```{math}
B[key]\leftarrow value
```

`ActionSelection` は child の `name()` または `registrationName()` と `node_name` を比較します。XML で同じ登録名の child を複数置く場合は、必要に応じて `name` 属性で一意名を付け、その名前を plan 側に書きます。
