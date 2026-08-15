セットアップ
============

対象環境
--------

この手順は ``/home/yuki/rogi_nav_ws/src/rogi_nav`` の現在の構成を前提にしています。
ホスト環境で使う場合は Ubuntu 24.04 と ROS 2 Jazzy を想定しています。
Docker を使う場合は、リポジトリの ``Dockerfile`` と ``Makefile`` から Jazzy 環境を作成できます。

ホスト環境でのセットアップ
--------------------------

ワークスペースを作成し、リポジトリを ``src`` 配下に配置します。

.. code-block:: bash

   mkdir -p ~/rogi_nav_ws/src
   cd ~/rogi_nav_ws/src
   git clone git@github.com:KeioRoboticsAssociation/rogi_nav.git
   cd rogi_nav

共通ツールと外部依存を取得・ビルドします。

.. code-block:: bash

   make setup

``make setup`` は主に次を実行します。

* apt 依存の導入
* ``common_tool/common_tool.repos`` による外部リポジトリの取得
* ``common_tool/BehaviorTree.CPP`` の CMake ビルドと ``common_tool/install`` へのインストール
* ``common_tool/Groot`` の submodule 取得とビルド

セットアップ済み環境で外部ツールや Python 依存を更新する場合は次を使います。

.. code-block:: bash

   make sync

ROS 依存を解決してワークスペースをビルドします。

.. code-block:: bash

   cd ~/rogi_nav_ws
   source /opt/ros/jazzy/setup.bash
   rosdep install --from-paths src --ignore-src -r -y
   colcon build --symlink-install
   source install/setup.bash

サンプル起動
------------

実機向けの sample profile は ``real``、シミュレーション向けは ``sim`` です。

.. code-block:: bash

   ros2 launch rogi_nav_sample sample.launch.py config_profile:=real

.. code-block:: bash

   ros2 launch rogi_nav_sample sample.launch.py config_profile:=sim

``sample.launch.py`` は内部で ``rogi_launch/launch/rogi_nav.launch.py`` を呼び出します。
設定は ``example/sample/config`` 配下から読み込まれます。

直接 ``rogi_nav.launch.py`` を使う場合は、設定ディレクトリと profile を指定します。

.. code-block:: bash

   ros2 launch rogi_launch rogi_nav.launch.py \
     config_dir:=/home/yuki/rogi_nav_ws/src/rogi_nav/example/sample/config \
     config_profile:=sim

主要な設定ファイル
------------------

.. list-table::
   :header-rows: 1
   :widths: 32 68

   * - ファイル
     - 役割
   * - ``example/sample/config/real.yaml``
     - 実機向け profile。Gazebo を止め、picoScan、wheel odometry、MAVLink/RS485、制御系を有効化します。
   * - ``example/sample/config/sim.yaml``
     - シミュレーション向け profile。Gazebo、可視化、Web 表示、自己位置推定、pure pursuit を有効化します。
   * - ``example/sample/config/simulation/config.yaml``
     - Gazebo の model、world、sim time、odom drift などを設定します。
   * - ``example/sample/config/map/config.yaml``
     - 地図 CSV と Gazebo 壁生成パラメータを設定します。
   * - ``example/sample/config/sensing/config.yaml``
     - LiDAR、scan merger、RANSAC line detector の設定です。
   * - ``example/sample/config/localization/*/config.yaml``
     - ``emcl2`` または ``ransac_localizer`` の自己位置推定パラメータです。
   * - ``example/sample/config/tree/main.xml``
     - ``state_node`` が読む BehaviorTree です。
   * - ``example/sample/config/path/trajectory/*.csv``
     - ``simple_pure_pursuit`` と ``path_visualizer`` が読む経路 CSV です。

Docker でのセットアップ
-----------------------

Docker image をローカルでビルドします。

.. code-block:: bash

   cd ~/rogi_nav_ws/src/rogi_nav
   make build

GitHub Container Registry の image を使う場合は次を実行します。

.. code-block:: bash

   make pull

コンテナ内でシェルを開き、外部ツールをセットアップします。

.. code-block:: bash

   ssh -T git@github.com
   make shell
   make setup

シミュレーションを起動します。

.. code-block:: bash

   make run

launch 引数を渡す場合は ``LAUNCH_ARGS`` を使います。

.. code-block:: bash

   make run LAUNCH_ARGS="config_profile:=sim"

補助ツール
----------

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - コマンド
     - 内容
   * - ``make groot``
     - ビルド済み Groot を起動します。
   * - ``make trajectory-generator``
     - TrajectoryGenerator GUI を起動します。
   * - ``make map-builder``
     - map_builder の npm 依存を入れて開発サーバを起動します。
   * - ``make clean-common-tool``
     - ``common_tool`` 配下の生成物を削除します。

