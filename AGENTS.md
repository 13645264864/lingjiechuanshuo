# LINGJIECHUANSHUO 项目说明

## 项目与运行环境

- 项目类型：Godot 4 俯视角房间式战斗关卡
- 项目根目录：`F:\lingjiechuanshuo`
- Godot 版本：4.7.2 stable
- Godot 可执行文件：`F:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`
- 主场景：`res://main_menu.tscn`，点击“开始游戏”进入 `res://first_level.tscn`。
- 项目配置：`res://project.godot`

运行测试使用：

```powershell
& 'F:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' `
  --path 'F:\lingjiechuanshuo' `
  --headless --display-driver headless --audio-driver Dummy --quit-after 300
```

截至本文件创建时，主场景已通过上述无界面运行测试，玩家、GameManager、血条和修为条均成功初始化，进程退出码为 0。

## 当前架构

- `main_menu.tscn` / `main_menu.gd`：使用用户提供的 demon slayer.jpg 作为主页面背景，仅有“开始游戏”；进入关卡后直接开始初始技能选择。
- `touch_joystick.gd`：左侧浮动虚拟摇杆，以当前手指落点为中心，松手隐藏；移动方向与键盘合并，暂停、松手、旋转或切出应用时释放输入。
- `touch_action_button.gd`：直接接收多点触摸，允许左手移动同时右手闪避或发动剑魂。
- Android 使用兼容渲染、传感器横竖屏旋转、横屏 1152×648 / 竖屏 648×1152 基准缩放和内置 Noto Sans SC 字体。导出预设为 `Android`，版本 0.1.2（VersionCode 3），包名 `com.lingjiechuanshuo.demonslayer`。
- 发布 APK 为 `export/灵界传说-内测版.apk`。构建命令 `tools/build_android.ps1`；先用 `tools/prepare_android.py` 准备工具，再运行 `tools/android_signing.py` 和 Godot 编辑器脚本 `tools/configure_android.gd`。
- 发布签名私钥在 `.tmp/android/release.keystore`，凭据在同目录 signing.json；均排除出 Git，后续更新必须保留同一签名身份。

- `first_level.tscn`：当前默认第一关，六个普通战斗房与一个最终 Boss 房，清怪开门，最后拐弯位置有随机变化。
- `first_level_map.gd`：房间生成、图块、装饰、墙体碰撞、封门与房间状态；`first_level_camera.gd` 控制关卡相机。
- `level_minimap.gd`：右上角小地图，显示连线、当前房间、已清理房间及 Boss 图标。
- `archer.gd` / `enemy_arrow.gd`：用户提供的 Arcane Archer 远程小怪，抬弓预警、锁定射箭、视线判断和墙体阻挡。
- `sword_drop.gd` / `sword_form.gd` / `sword_skill_button.gd`：Boss 掉剑、拾取解锁、10 秒小型剑魔变身，50 秒冷却从发动时计算，支持 Q 与虚拟按钮。
- `training_dummy.tscn` / `training_dummy.gd`：拿到剑魂后在 Boss 房生成一次“练习人偶”，无限生命、固定位置、不攻击、不掉奖励，加入敌人组供火球与剑魂自动锁定，不计入房间清怪条件。
- 剑系升级为剑锋、连斩、剑气、影袭；拾剑后的专属三选一与普通升级排队处理，死亡优先关闭全部弹窗。
- 剑魂附身自动寻找同房间可见敌人，约每 2.5 秒安全闪现追斩、自动移动跟进连斩、每 2 秒释放基础剑气；方向输入可临时接管走位，自动追击不能穿墙或越过封闭房门。
- `altar_portal.gd`：Boss 死后在圆形遗迹上出现蓝色传送光效，拾剑和奖励选择完成后启用，正常形态靠近 100 世界单位触发；变身与自动追击不会误触，站在光圈内结束变身需离开后再进入。
- `beta_end_screen.gd`：传送后淡出到黑屏，显示用户指定的内测结束文字与“重玩”按钮，重玩重置第一关。
- `breakthrough_fx.gd`：升级时复制角色全身金光、金色粒子与大字“突破了！”，持续约 1.5 秒；先展示约 0.4 秒金光，再淡入升级选项，暂停时继续播放，连续升级刷新同一效果。
- 新回归 `tests/portal_breakthrough_sword.gd`：覆盖自动追击三招的真实命中、墙体/房门落点检查、输入干预、传送防误触、暂停下突破特效、黑屏结束与真实鼠标重玩；`-- --capture` 可输出桌面/手机截图。
- 地图原始 PNG 禁止单独转载，排除出 Git。新环境运行 `tools/import_cainos.ps1 -SourceDirectory <素材包目录>` 导入用户批准的素材。
- 运行地图试玩：使用 Godot 完整路径，加 `--path F:\lingjiechuanshuo res://first_level.tscn`。
- 第一关端到端回归：`--headless --audio-driver Dummy --fixed-fps 60 --script res://tests/first_level_map.gd`；覆盖实际走过通道、封门清怪、弓箭手、箭与墙碰撞、拾剑、升级排队、10/50 秒计时、变身伤害、手机布局、死亡与重开。截图额外移除 `--headless` 并添加 `-- --capture`。

- `main.tscn`：被第一关继承的基础场景，也用于旧战斗系统隔离回归测试。
- `player.gd`：WASD 移动、四方向动画、自动寻找最近敌人并发射火球、生命值和修为/境界系统。
- `enemy.gd`：敌人追踪、近战攻击、受伤反馈、死亡和灵气掉落。
- `fireball.gd`：火球移动、命中、伤害、分裂、高速、穿透和暴击 Buff；视觉使用用户提供的 FB00 五帧火球素材，精灵随飞行方向旋转，不使用额外程序化焰尾。
- `game_manager.gd`：开始游戏、计时、刷怪、Buff 三选一、死亡和重开。
- `aura_drop.gd`：玩家拾取灵气。
- `status_bar.gd`：血条、修为条和境界文本 UI。
- `camera_2d.gd`：跟随玩家并限制地图边界。
- `damage_label.gd`：飘字伤害显示。
- `main.gd`：较早的刷怪逻辑遗留脚本；当前主场景使用 `GameManager`，修改刷怪流程时优先检查 `game_manager.gd`。

## 当前玩法功能

- 玩家自动锁定范围内最近敌人并发射火球。
- 第一关敌人在进入房间时生成并追踪玩家，房间清理后不再重复刷怪。
- 敌人死亡掉落灵气，灵气累计后提升境界。
- 境界提升时出现三选一 Buff：分裂、高速、穿透、巨型火球/暴击。
- 支持开始游戏、计时、死亡界面和重新开始。
- 旧生存场景的普通敌人从相机可见区域外生成，出生点与玩家保持至少 350 世界单位的安全距离。
- 普通敌人按游戏分钟成长：生命值 `1.18^分钟`，攻击力 `1.12^分钟`，移动速度每分钟增加 3.5%，最多增加 45%。
- 第一关最终房间生成一次 Boss，旧生存场景保留分钟刷 Boss；Boss 拥有独立皮肤、冲刺动作、属性曲线和顶部血条。
- 玩家可按 Shift 或点击“闪避 SHIFT”按钮，贴地保持奔跑姿态冲刺约 300 世界单位，保留霓虹重影、无敌帧和短暂结束保护。
- Boss 根节点保持 1 倍，独立贴图和碰撞体按同一目标尺寸设置，为普通小怪的 2 倍（320 世界单位）；后续境界不再增加体型，脚下法阵同步缩小。
- 闪避期间会关闭玩家碰撞层、碰撞遮罩和自身碰撞形状，因此可以真正穿过敌人实体；闪避结束后恢复正常碰撞。

## 版本控制

- Git 分支：`main`
- GitHub 远程仓库：<https://github.com/13645264864/lingjiechuanshuo>
- Godot 生成的 `.godot/` 目录已在 `.gitignore` 中排除。
- 推送命令：

```powershell
git push -u origin main
```

如果推送失败，先检查当前网络是否能连接 GitHub 的 TCP 443 端口；浏览器能访问 GitHub 不一定代表终端网络也已连通。

## 修改与验证约定

- 修改场景、脚本或资源后，使用项目指定的 Godot 4.7.2 运行主场景验证。
- 优先使用无界面启动检查资源加载和脚本初始化，再进行需要交互的手动测试。
- 不要把“终端找不到 Godot 命令”误判为项目不能运行；应先使用上面记录的完整可执行文件路径。

## 火球技能回归测试

- 火球在加入场景树之前初始化，玩家必须把 `GameManager.get_fireball_config()` 的配置显式传入 `setup()`；不要在入树前通过绝对路径寻找 GameManager。
- 分裂在主火球发射瞬间生成，不等待命中；次级火球继承主火球配置，但不会递归分裂。
- 分裂数量按品质为 2、3、6、12 个。
- 巨型火球按品质逐级放大，缩放为 1.8、2.4、3.2、4.2；根节点缩放同时扩大图像和碰撞范围。
- 巨型火球会结算同一碰撞批次内覆盖到的多个敌人，体积越大实际群体命中范围越大。
- 使用 console 可执行文件等待进程完成、检查退出码和完整日志。仅收到引擎启动横幅或没有报错输出不能证明测试通过。
- 自动测试会触发真实按钮信号、玩家发射和物理碰撞，覆盖四类技能的各品质、分裂继承、暴击、突破和重开。

```powershell
& 'F:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' `
  --path 'F:\lingjiechuanshuo' --headless --audio-driver Dummy `
  --fixed-fps 60 --script res://tests/fireball_buffs.gd
```

成功输出 `BUFF_TEST_RESULT ... failures=0`，退出码为 0。有画面的视觉检查可移除 `--headless`，并在命令末尾添加 `-- --capture`，截图写入 `.godot/buff-visual-check.png`。

Boss、刷怪和闪避系统回归测试：

```powershell
& 'F:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' `
  --path 'F:\lingjiechuanshuo' --headless --audio-driver Dummy `
  --fixed-fps 60 --script res://tests/systems_boss_dodge.gd
```

成功输出 `SYSTEM_TEST_RESULT ... failures=0`，退出码为 0。

## Boss 素材审核与攻击测试

- 新 Boss 外观素材必须先展示候选图，经过用户审核后才可接入游戏。
- 当前用户已批准 CreativeKind 的 NightBorne Warrior，保留黑甲紫剑的外观。
- NightBorne 的原始素材禁止单独转载，因此 `Sprites/nightborne/` 中的图片排除出 Git；新环境先运行 `tools/fetch_nightborne.ps1` 从作者官网下载。
- Boss 使用左右朝向的真实像素动作，不宣称拥有独立的八方向动画。
- 长突进距离为 650～1100 世界单位；蓄力阶段追踪，最后 0.16 秒锁向，突进期间不转弯，斩后恢复 0.75 秒。
- 攻击判定使用 Godot 物理查询；高速突进进行连续扫掠，不依赖接触伤害或仅检查最终落点。
- `tests/boss_attacks.gd` 验证实际命中、持续跑动的追击压力、锁向后横向闪避、追踪灵剑、预判剑阵、火球反击和死亡取消攻击。
- `tests/boss_animation.gd` 验证批准素材的动作帧、状态机自动出招、死亡动画和掉落；带 `-- --capture` 可生成实机帧，再用 `python tools/make_boss_preview.py` 生成动态预览。

```powershell
& 'F:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' `
  --path 'F:\lingjiechuanshuo' --headless --audio-driver Dummy `
  --fixed-fps 60 --script res://tests/boss_attacks.gd
```

成功输出 `BOSS_ATTACK_TEST_RESULT ... failures=0`，退出码为 0。
