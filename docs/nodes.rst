ノード構成
==========

全体構成
--------

``rogi_launch/launch/rogi_nav.launch.py`` が、profile YAML を読み込んで各 component launch を組み合わせます。
多くの C++ ノードは ``rclcpp_components`` の composable node として実装され、必要に応じて
``component_container_mt`` にロードされます。

``example/sample/config/real.yaml`` と ``example/sample/config/sim.yaml`` の
``launch.components`` で、コンポーネント単位またはノード単位に有効/無効を切り替えます。

Launch profile
--------------

.. list-table::
   :header-rows: 1
   :widths: 22 28 50

   * - profile
     - 主な用途
     - 特徴
   * - ``real``
     - 実機
     - Gazebo と Web を無効化し、picoScan、wheel odometry、MAVLink/RS485、DC motor command 変換を有効化します。
   * - ``sim``
     - Gazebo シミュレーション
     - Gazebo、RViz、Web 表示、地図、scan merger、line detector、自己位置推定、pure pursuit、state node を有効化します。

Map
---

.. list-table::
   :header-rows: 1
   :widths: 24 28 48

   * - ノード
     - 実行ファイル / plugin
     - 説明
   * - ``map_loader``
     - ``rogi_map`` / ``map_loader::map_loader``
     - ``line_segments.csv`` と ``circles.csv`` を読み込み、``rogi_msgs/msg/Map`` を publish します。
   * - ``map_converter``
     - ``rogi_map`` / ``map_converter::map_converter``
     - ``rogi_msgs/msg/Map`` を ``nav_msgs/msg/OccupancyGrid`` に変換します。

主な interface は次の通りです。

.. list-table::
   :header-rows: 1
   :widths: 24 20 28 28

   * - ノード
     - 種別
     - 名前
     - 型 / 内容
   * - ``map_loader``
     - publish
     - ``map`` remap 後 ``/raw_map``
     - ``rogi_msgs/msg/Map``
   * - ``map_loader``
     - parameter
     - ``line_segments_path``, ``circles_path``
     - 地図 CSV path
   * - ``map_converter``
     - subscribe
     - ``map`` remap 後 ``/raw_map``
     - ``rogi_msgs/msg/Map``
   * - ``map_converter``
     - publish
     - ``occupancy_grid`` remap 後 ``/map``
     - ``nav_msgs/msg/OccupancyGrid``
   * - ``map_converter``
     - parameter
     - ``resolution``
     - OccupancyGrid 解像度

Sensing
-------

.. list-table::
   :header-rows: 1
   :widths: 24 28 48

   * - ノード
     - 実行ファイル / plugin
     - 説明
   * - ``sick_generic_caller``
     - ``sick_scan_xd``
     - SICK picoScan などの LiDAR driver を起動します。設定は ``sensing/config.yaml`` の ``sick_picoscan`` で行います。
   * - ``scan_merger``
     - ``rogi_lidar_merger`` / ``rogi_lidar_merger::ScanMerger``
     - 複数 LiDAR の ``LaserScan`` を共通 frame に統合します。
   * - ``line_detector``
     - ``rogi_ransac`` / ``line_detector::line_detector``
     - ``LaserScan`` から RANSAC で直線、線分、角を検出します。

.. list-table::
   :header-rows: 1
   :widths: 24 20 28 28

   * - ノード
     - 種別
     - 名前
     - 型 / 内容
   * - ``scan_merger``
     - subscribe
     - ``scan_topics``
     - ``sensor_msgs/msg/LaserScan`` の配列
   * - ``scan_merger``
     - publish
     - ``merged_scan`` remap 後 ``/scan_for_localization``
     - ``sensor_msgs/msg/LaserScan``
   * - ``scan_merger``
     - parameter
     - ``frame_id``, ``frequency``, ``angle_*``, ``range_*``
     - 出力 scan の frame と範囲
   * - ``line_detector``
     - subscribe
     - ``scan``
     - ``sensor_msgs/msg/LaserScan``
   * - ``line_detector``
     - publish
     - ``lines``, ``line_segments``, ``corners``
     - ``rogi_msgs`` と ``PoseArray``
   * - ``line_detector``
     - parameter
     - ``max_iterations``, ``max_lines``, ``distance_threshold`` など
     - RANSAC 検出条件

Localization
------------

.. list-table::
   :header-rows: 1
   :widths: 24 28 48

   * - ノード
     - 実行ファイル / plugin
     - 説明
   * - ``emcl2``
     - ``emcl2`` / ``emcl2::EMcl2Node``
     - LiDAR と OccupancyGrid を使う particle filter 系の自己位置推定です。
   * - ``ransac_localizer``
     - ``rogi_ransac_localizer`` / ``rogi_ransac_localizer::RansacLocalizer``
     - 地図の線分と観測線分を対応付けて pose を補正します。
   * - ``wheel_odometry``
     - ``wheel_odometry_node``
     - Rogidrive encoder 情報から omni wheel odometry を計算します。

.. list-table::
   :header-rows: 1
   :widths: 24 20 28 28

   * - ノード
     - 種別
     - 名前
     - 型 / 内容
   * - ``emcl2``
     - subscribe
     - ``scan``, ``map``, ``initialpose``
     - ``LaserScan``, ``OccupancyGrid``, ``PoseWithCovarianceStamped``
   * - ``emcl2``
     - publish
     - ``localization_pose``, ``particlecloud``, ``alpha``
     - 推定 pose、particle、信頼度
   * - ``emcl2``
     - service
     - ``global_localization``
     - ``std_srvs/srv/Empty``
   * - ``ransac_localizer``
     - subscribe
     - ``map``, ``odom``, ``line_segments``
     - 地図、odometry、観測線分
   * - ``ransac_localizer``
     - publish
     - ``localization_pose``
     - ``geometry_msgs/msg/PoseWithCovarianceStamped``
   * - ``wheel_odometry``
     - subscribe
     - ``/rogidrive_status``
     - Rogidrive status
   * - ``wheel_odometry``
     - publish
     - ``/odom``
     - ``nav_msgs/msg/Odometry``
   * - ``wheel_odometry``
     - tf
     - ``odom`` -> ``base_link``
     - ``publish_tf`` が true の場合に publish

Control
-------

.. list-table::
   :header-rows: 1
   :widths: 24 28 48

   * - ノード
     - 実行ファイル / plugin
     - 説明
   * - ``simple_pure_pursuit``
     - ``simple_pure_pursuit_node`` / ``simple_pure_pursuit::SimplePurePursuitNode``
     - 経路 CSV を読み込み、``FollowPath`` action の goal に応じて ``/cmd_vel`` を生成します。
   * - ``cmd_vel_to_dcmotor_node``
     - ``cmd_vel_to_dcmotor_node`` / ``cmd_vel_to_dcmotor::CmdVelToDCMotorNode``
     - ``geometry_msgs/msg/Twist`` を Rogidrive の motor command に変換します。

.. list-table::
   :header-rows: 1
   :widths: 24 20 28 28

   * - ノード
     - 種別
     - 名前
     - 型 / 内容
   * - ``simple_pure_pursuit``
     - action server
     - ``follow_path``
     - ``rogi_msgs/action/FollowPath``
   * - ``simple_pure_pursuit``
     - subscribe
     - ``/localization_pose``, ``/robot_pose``
     - 現在 pose
   * - ``simple_pure_pursuit``
     - publish
     - ``/cmd_vel``, ``/pure_pursuit_path``, ``/distance_to_goal``, ``/current_follow_path_index``
     - 速度指令、可視化、状態
   * - ``cmd_vel_to_dcmotor_node``
     - subscribe
     - ``/cmd_vel``
     - ``geometry_msgs/msg/Twist``
   * - ``cmd_vel_to_dcmotor_node``
     - publish
     - ``/rogidrive_cmd``
     - Rogidrive motor command
   * - ``cmd_vel_to_dcmotor_node``
     - parameter
     - ``wheel_radius``, ``center_to_wheel``, ``motor_names`` など
     - omni wheel と motor の変換条件

State / BehaviorTree
--------------------

.. list-table::
   :header-rows: 1
   :widths: 24 28 48

   * - ノード
     - 実行ファイル / plugin
     - 説明
   * - ``state_node``
     - ``state_node`` / ``state::StateNode``
     - BehaviorTree XML を 10 ms 周期で tick し、状態遷移と action 実行を管理します。
   * - ``groot``
     - ``common_tool/Groot/build/Groot``
     - BehaviorTree の monitor GUI です。``enable_groot`` が true のとき起動します。

``state_node`` は ``tree_path`` で指定した XML を読みます。
現在登録されている主な BT action は次の通りです。

.. list-table::
   :header-rows: 1
   :widths: 24 76

   * - Action
     - 内容
   * - ``FollowPath``
     - ``follow_path`` action client として ``simple_pure_pursuit`` に経路番号を送ります。
   * - ``WaitStart``
     - ``/start`` の ``std_msgs/msg/Bool`` を待ちます。

Visualization
-------------

.. list-table::
   :header-rows: 1
   :widths: 24 28 48

   * - ノード
     - 実行ファイル / plugin
     - 説明
   * - ``rviz2``
     - ``rviz2``
     - ``visualization/config.yaml`` の RViz config で起動します。
   * - ``line_segments_visualizer``
     - ``rogi_visualizer`` / ``line_segments_visualizer::line_segments_visualizer``
     - ``line_segments`` を RViz marker に変換します。
   * - ``path_visualizer``
     - ``rogi_visualizer`` / ``path_visualizer::path_visualizer``
     - 経路 CSV と現在経路 index から ``nav_msgs/msg/Path`` を publish します。

Simulator
---------

``gazebo_simulator`` package は Gazebo Harmonic 向けの launch、URDF、world、補助 Python node を提供します。

.. list-table::
   :header-rows: 1
   :widths: 24 28 48

   * - ノード
     - 実行ファイル
     - 説明
   * - ``sensor_topic_converters``
     - ``sensor_topic_converters.py``
     - Gazebo bridge 後の sensor topic を rogi_nav 側で扱いやすい topic に変換します。
   * - ``odom_drift_simulator``
     - ``odom_drift_simulator.py``
     - ``/odom_raw`` に scale、drift、noise を加えて ``/odom`` を publish します。
   * - ``odom_tf_broadcaster``
     - ``odom_tf_broadcaster.py``
     - odometry から ``odom`` -> ``base_link`` の TF と pose marker を publish します。
   * - ``scan_frame_normalizer``
     - ``scan_frame_normalizer.py``
     - ``LaserScan`` の frame_id を localization 用に揃えます。
   * - ``pose_comparison_gui``
     - ``pose_comparison_gui.py``
     - 真値 odometry と推定 pose を比較表示します。

``simple_sim.launch.py`` の主な引数は ``model``、``world``、``use_simple_world``、
``use_sim_time``、``headless``、``enable_odom_drift``、``line_segments_path``、
``circles_path``、``wall_height``、``wall_thickness`` です。

Messages / Actions
------------------

``rogi_msgs`` は地図、線分、円、経路追従 action を提供します。

.. list-table::
   :header-rows: 1
   :widths: 34 66

   * - interface
     - 用途
   * - ``rogi_msgs/msg/Map``
     - map loader と localization が使う独自地図表現です。
   * - ``rogi_msgs/msg/LineSegmentArray``
     - RANSAC line detector と visualizer/localizer が使う観測線分です。
   * - ``rogi_msgs/msg/LineArray``
     - 検出された直線です。
   * - ``rogi_msgs/msg/CircleArray``
     - 地図上の円形 feature です。
   * - ``rogi_msgs/action/FollowPath``
     - BehaviorTree/state node から pure pursuit に経路追従を要求します。
