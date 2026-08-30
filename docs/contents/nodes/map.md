# Map

地図系ノードは、CSV で管理する幾何地図を ROS message と grid map に変換します。

| ノード | 実行ファイル / plugin | 説明 |
| --- | --- | --- |
| `map_loader` | `rogi_map` / `map_loader::map_loader` | `line_segments.csv` と `circles.csv` を読み込み、`rogi_msgs/msg/Map` を publish します。 |
| `map_converter` | `rogi_map` / `map_converter::map_converter` | `rogi_msgs/msg/Map` を `nav_msgs/msg/OccupancyGrid` に変換します。 |

```{toctree}
:maxdepth: 1

map/map-loader
map/map-converter
```
