# ホスト環境でのセットアップ

ワークスペースを作成し、リポジトリを `src` 配下に配置します。

```bash
mkdir -p ~/rogi_nav_ws/src
cd ~/rogi_nav_ws/src
git clone git@github.com:KeioRoboticsAssociation/rogi_nav.git
cd rogi_nav
```

共通ツールと外部依存を取得・ビルドします。

```bash
make setup
```

`make setup` は主に次を実行します。

- apt 依存の導入
- `common_tool/common_tool.repos` による外部リポジトリの取得
- `common_tool/BehaviorTree.CPP` の CMake ビルドと `common_tool/install` へのインストール
- `common_tool/Groot` の submodule 取得とビルド

セットアップ済み環境で外部ツールや Python 依存を更新する場合は次を使います。

```bash
make sync
```

ROS 依存を解決してワークスペースをビルドします。

```bash
cd ~/rogi_nav_ws
source /opt/ros/jazzy/setup.bash
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
source install/setup.bash
```
