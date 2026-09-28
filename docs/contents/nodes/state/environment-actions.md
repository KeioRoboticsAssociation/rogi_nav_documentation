# 地図・自己位置推定・Gazebo の切替

`state_node` に登録された3つの非同期 BT action です。サービスが利用可能になるまで、送信後は応答が届くまで `RUNNING` を返します。応答の `success=true` で `SUCCESS`、不正な入力や失敗応答で `FAILURE` になります。待機のタイムアウトはありません。

| 登録名 | input port | ROS interface |
| --- | --- | --- |
| `SetLocalizationMode` | `mode`: `ransac` / `odom_only` | `/localization/set_ransac_enabled` (`std_srvs/srv/SetBool`) |
| `SetMapArea` | `area`: `ground` / `level_1` | `/map/set_level_1` (`std_srvs/srv/SetBool`) |
| `LevelRobot` | `z` [m]、`model_name`（default `robot`） | `/world/nhk_2027/set_pose` (`ros_gz_interfaces/srv/SetEntityPose`)、`/odom_raw` 購読 |

## SetLocalizationMode

`ransac` で `data=true`、`odom_only` で `data=false` を送ります。odom_only では現在の補正 pose から odometry による伝播を継続します。開始位置を原点へリセットする機能ではありません。ransac への切替成功は補正の有効化を意味し、再捕捉完了まで待つことはありません。捕捉状態は `/localization/ransac_state` で確認します。

```xml
<Action ID="SetLocalizationMode" mode="odom_only"/>
<Action ID="FollowPath" path_index="1"/>
<Action ID="SetLocalizationMode" mode="ransac"/>
```

このサービスは RANSAC localizer が提供します。`localization.method: emcl2` の構成では本 action に必要なサービスは起動しません。

## SetMapArea

`ground` で `data=false`、`level_1` で `data=true` を送り、`map_loader` の配信地図を変更します。level_1 の線分・円 CSV を両方読み込めていない場合は切替に失敗します。

```xml
<Action ID="SetMapArea" area="level_1"/>
```

mode / area は小文字に変換して判定します。これらの action は halt 時にローカルの送信状態をリセットしますが、送信済みサービス要求の取消や切替の巻き戻しはしません。

## LevelRobot

`/odom_raw` の最新の x・y・yaw を保持し、指定した z にモデルを置いて roll・pitch を 0 にします。odom 未受信時も `RUNNING` で待機します。

```xml
<Action ID="LevelRobot" model_name="robot" z="0.71"/>
```

現在のサービス名は world `nhk_2027` に固定されています。実機の姿勢制御を行う action ではなく、Gazebo のモデル姿勢を直接変更します。

nhk_2027 の `tree/main.xml` は開始待ち → ground / ransac → 経路0 → 高さ0.11 mで水平化 → 1秒待機 → odom_only / 経路1 → 高さ0.71 mで水平化 → level_1 / ransac → 経路2・3・4（各終了後に水平化）の順です。
