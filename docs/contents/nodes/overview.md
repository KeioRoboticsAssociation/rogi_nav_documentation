# 全体構成

`rogi_launch/launch/rogi_nav.launch.py` が、profile YAML を読み込んで各 component launch を組み合わせます。
多くの C++ ノードは `rclcpp_components` の composable node として実装され、必要に応じて
`component_container_mt` にロードされます。

`example/sample/config/real.yaml` と `example/sample/config/sim.yaml` の
`launch.components` で、コンポーネント単位またはノード単位に有効/無効を切り替えます。
