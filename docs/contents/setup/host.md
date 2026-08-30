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
