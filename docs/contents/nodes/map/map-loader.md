# map_loader

## 役割

`map_loader` は CSV 地図を `rogi_msgs/msg/Map` に変換して publish します。線分と円弧を 1 つの map message にまとめ、`map_converter`、`ransac_localizer`、可視化ノードへ渡します。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| publish | `map` remap 後 `/raw_map` | `rogi_msgs/msg/Map` |
| parameter | `line_segments_path` | 線分 CSV path |
| parameter | `circles_path` | 円弧 CSV path |
| parameter | `reverse_y` | y 軸反転の有効化 |
| parameter | `reverse_y_offset` | y 軸反転後に足す offset |

## 座標変換

線分の始点と終点を {math}`p_s=(x_s,y_s,z_s)`、{math}`p_e=(x_e,y_e,z_e)` とします。`reverse_y=false` ならそのまま publish します。`reverse_y=true` の場合、y 座標だけを次式で反転します。

```{math}
y' = -y + y_0
```

ここで {math}`y_0` は `reverse_y_offset` です。

```{math}
p'_s=(x_s,-y_s+y_0,z_s), \qquad
p'_e=(x_e,-y_e+y_0,z_e)
```

円弧は中心 {math}`c=(x_c,y_c,z_c)`、半径 {math}`r`、開始角 {math}`\theta_s`、終了角 {math}`\theta_e` として読みます。y 軸反転時は次式です。

```{math}
c'=(x_c,-y_c+y_0,z_c), \qquad
\theta'_s=-\theta_s, \qquad
\theta'_e=-\theta_e
```

## Publish

publisher は `transient_local + reliable` です。起動直後に publish し、その後 500 ms 間隔で数回再送します。静的地図を想定しているため、再送後は timer を停止します。

## 設定ファイル

sample では `example/sample/config/map/config.yaml` がこのノードの入力ファイルを指定します。

| key | 例 | 対応する parameter / 用途 |
| --- | --- | --- |
| `map.line_segments_path` | `line_segments.csv` | `line_segments_path` に渡される線分 CSV |
| `map.circles_path` | `circles.csv` | `circles_path` に渡される円弧 CSV |
| `topics.raw_map` | `/raw_map` | `map` publisher の remap 先 |
| `topics.map` | `/map` | 後段 `map_converter` の出力 topic |

`rogi_nav.launch.py` は `config_dir/map` を基準に相対 path を絶対 path へ変換します。

```{math}
P_{\mathrm{line}}=\operatorname{join}(D_{\mathrm{map}},\mathrm{line\_segments\_path})
```

```{math}
P_{\mathrm{circle}}=\operatorname{join}(D_{\mathrm{map}},\mathrm{circles\_path})
```

`line_segments.csv` は header 後に次の 6 列を持ちます。

```text
start_x,start_y,start_z,end_x,end_y,end_z
```

`circles.csv` は次の 6 列です。

```text
center_x,center_y,center_z,radius,start_angle,end_angle
```

profile 側では `real.yaml` / `sim.yaml` の次の key で起動を切り替えます。

```yaml
launch:
  components:
    map:
      map_loader:
        enabled: true
```
