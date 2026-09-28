# map_converter

## 役割

`map_converter` は `rogi_msgs/msg/Map` を `nav_msgs/msg/OccupancyGrid` に rasterize します。`emcl2` はこの grid から尤度場を作ります。

## Interface

| 種別 | 名前 | 型 / 内容 |
| --- | --- | --- |
| subscribe | `map` remap 後 `/raw_map` | `rogi_msgs/msg/Map` |
| publish | `occupancy_grid` remap 後 `/map` | `nav_msgs/msg/OccupancyGrid` |
| parameter | `resolution` | grid 解像度 {math}`\Delta` [m/cell] |

## Grid 定義

入力 map の bounding box を {math}`[x_{\min},x_{\max}]\times[y_{\min},y_{\max}]` とします。

```{math}
W=\left\lfloor\frac{x_{\max}-x_{\min}}{\Delta}\right\rfloor+1,\qquad
H=\left\lfloor\frac{y_{\max}-y_{\min}}{\Delta}\right\rfloor+1
```

world 座標から grid index への変換は次式です。

```{math}
i=\left\lfloor\frac{x-x_{\min}}{\Delta}\right\rfloor,\qquad
j=\left\lfloor\frac{y-y_{\min}}{\Delta}\right\rfloor
```

初期 cell 値は `0`、占有 cell は `100` です。

## 線分 rasterize

grid 上の始点を {math}`(i_0,j_0)`、終点を {math}`(i_1,j_1)` とします。

```{math}
d_i=|i_1-i_0|,\quad d_j=|j_1-j_0|,\quad
s_i=\operatorname{sign}(i_1-i_0),\quad s_j=\operatorname{sign}(j_1-j_0)
```

Bresenham 型に誤差 {math}`e=d_i-d_j` を更新します。

```{math}
2e>-d_j \Rightarrow e\leftarrow e-d_j,\ i\leftarrow i+s_i
```

```{math}
2e<d_i \Rightarrow e\leftarrow e+d_i,\ j\leftarrow j+s_j
```

各 step の {math}`(i,j)` を `100` にします。`start.z` と `end.z` がどちらも 0 でない線分は無視します。

## 円弧 rasterize

円弧上の点は次式です。

```{math}
p(\theta)=
\begin{bmatrix}
x_c+r\cos\theta\\
y_c+r\sin\theta
\end{bmatrix}
```

円弧境界の分割数は次式です。`center.z != 0` の円は rasterize しません。

```{math}
N=\mathrm{circle\_approximation\_segments}
```

```{math}
\theta_k=\theta_s+\frac{k}{N}(\theta_e-\theta_s),\qquad k=0,\dots,N
```

隣接サンプルを Bresenham で結び、さらに cell 中心 {math}`q=(x,y)` が次を満たすとき占有にします。

```{math}
\|q-c\|^2\le r^2
```

full circle でない場合は、角度 {math}`\phi=\operatorname{atan2}(y-y_c,x-x_c)` が sweep 内にあることも条件です。

```{math}
\operatorname{wrap}_{[0,2\pi)}(\phi-\theta_s)\le \theta_e-\theta_s
```

上式は正の sweep の場合です。負の sweep では開始角から逆向きに判定します。角度幅がほぼ 0、またはほぼ 2π 以上なら円全体を塗りつぶします。

## 設定ファイル

`map/config.yaml` の次の設定を統合 launch から渡します。

```yaml
map_converter:
  ros__parameters:
    resolution: 0.01
    circle_approximation_segments: 50
```

`resolution` は m/cell、`circle_approximation_segments` は円弧の境界・外接範囲を計算する分割数で、正の整数が必要です。`launch.components.map.map_converter.parameters` でも上書きできます。起動可否は同じ階層の `enabled`、入出力は `topics.raw_map` / `topics.map` で設定します。
