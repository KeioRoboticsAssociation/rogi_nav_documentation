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
