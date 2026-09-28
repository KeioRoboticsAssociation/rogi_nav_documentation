# ホスト環境でのセットアップ

基本は、リポジトリ取得、外部ツール準備、ROS ワークスペースビルドの 3 ステップです。

```bash
mkdir -p ~/rogi_nav_ws/src
cd ~/rogi_nav_ws/src
git clone git@github.com:KeioRoboticsAssociation/rogi_nav.git
cd rogi_nav
make setup

cd ~/rogi_nav_ws
source /opt/ros/jazzy/setup.bash
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
source install/setup.bash
```

更新だけ行う場合は `~/rogi_nav_ws/src/rogi_nav` で `make sync` を実行し、その後に必要なら `colcon build --symlink-install` を再実行します。

`make setup` は apt 依存、`common_tool/common_tool.repos` の取り込み、BehaviorTree.CPP v3.8 / Groot のビルドに加え、`sick_scan_xd` を専用の build/install ディレクトリでビルドします。ドライバの取得元は同ファイルに定義された `sick_scan_zero_copy` リポジトリです。MAVLink_ros2、rogidrive、TrajectoryGenerator、map_builder、Web などの非公開リポジトリには SSH でアクセスできる必要があります。

`make sync` は apt、外部リポジトリ、`uv` 依存を更新し、SICK ドライバを再ビルドします。補助ツールは `common_tool/COLCON_IGNORE` により通常の ROS ワークスペース探索から分離されています。
