# セットアップ

最短手順は次の通りです。

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

起動は profile を 1 つ選ぶだけです。

```bash
ros2 launch rogi_nav_sample sample.launch.py config_profile:=sim
```

実機では `config_profile:=real` を使います。Docker を使う場合は `cd ~/rogi_nav_ws/src/rogi_nav && make run` で同じ sample launch が起動します。

```{toctree}
:maxdepth: 2

setup/host
setup/sample-launch
setup/config-files
setup/docker
setup/target-environment
setup/tools
```
