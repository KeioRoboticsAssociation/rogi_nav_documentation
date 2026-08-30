# Map

| ノード | 実行ファイル / plugin | 説明 |
| --- | --- | --- |
| `map_loader` | `rogi_map` / `map_loader::map_loader` | `line_segments.csv` と `circles.csv` を読み込み、`rogi_msgs/msg/Map` を publish します。 |
| `map_converter` | `rogi_map` / `map_converter::map_converter` | `rogi_msgs/msg/Map` を `nav_msgs/msg/OccupancyGrid` に変換します。 |

主な interface は次の通りです。

| ノード | 種別 | 名前 | 型 / 内容 |
| --- | --- | --- | --- |
| `map_loader` | publish | `map` remap 後 `/raw_map` | `rogi_msgs/msg/Map` |
| `map_loader` | parameter | `line_segments_path`, `circles_path` | 地図 CSV path |
| `map_converter` | subscribe | `map` remap 後 `/raw_map` | `rogi_msgs/msg/Map` |
| `map_converter` | publish | `occupancy_grid` remap 後 `/map` | `nav_msgs/msg/OccupancyGrid` |
| `map_converter` | parameter | `resolution` | OccupancyGrid 解像度 |

## `map_loader`

`map_loader` は CSV で管理している競技フィールド形状を ROS topic に載せる入口です。`line_segments_path` から線分、`circles_path` から円弧または円を読み込み、1 つの `rogi_msgs/msg/Map` にまとめて publish します。publisher は `transient_local + reliable` の QoS なので、後から起動した `map_converter` や localizer も最後の地図を受け取れます。

線分 CSV は先頭行を header として読み飛ばし、以降を `start.x,start.y,start.z,end.x,end.y,end.z` として解釈します。`#` で始まる行は無視されます。円 CSV は `center.x,center.y,center.z,radius,start_angle,end_angle` として読み込みます。`reverse_y` が true の場合は y 座標を `-y + reverse_y_offset` に反転し、円の開始角と終了角も符号反転します。これは CAD や作図ツールの座標系と ROS の map 座標系が上下反転している場合に使います。

地図は起動直後に 1 回 publish され、その後 500 ms 間隔で数回再送されます。静的地図を想定しているため、一定回数 publish した後は timer を停止します。地図ファイルを更新した場合はノード再起動が必要です。

## `map_converter`

`map_converter` は `rogi_msgs/msg/Map` を `nav_msgs/msg/OccupancyGrid` に rasterize します。`emcl2` の尤度場は `OccupancyGrid` を入力にするため、線分・円弧表現の地図を grid 表現に変換する橋渡しです。

処理は、まずすべての線分端点と円弧上のサンプル点から地図の bounding box を求めます。grid の原点は bounding box の `min_x, min_y`、幅と高さは `(max - min) / resolution + 1` です。初期値は全 cell が free 相当の `0` で、占有 cell は `100` に設定されます。

線分は Bresenham 型の整数 grid line drawing で塗られます。world 座標を grid index に変換し、x/y の誤差項を更新しながら始点から終点まで連続 cell を `100` にします。`start.z` と `end.z` がどちらも 0 でない線分は 2D 地図に投影しないため無視されます。

円弧は 2 段階で処理します。最初に半径と解像度から `max(10, radius / resolution * 8)` 個程度の角度サンプルを作り、隣り合うサンプル点を Bresenham で結んで円弧の輪郭を塗ります。次に円の bounding box 内の cell 中心を走査し、半径内かつ `start_angle` から `end_angle` の扇形内にある cell を占有にします。`start_angle` と `end_angle` が同じ、またはほぼ一周の場合は full circle として塗りつぶします。

出力 grid の `frame_id` は `map` です。解像度を細かくすると地図形状は精密になりますが、grid サイズと EMCL の尤度場生成コストが増えます。自己位置推定用なら、LiDAR のノイズ幅と `laser_likelihood_max_dist` とのバランスを見て調整します。
