# LINGJIECHUANSHUO 项目说明

## 项目与运行环境

- 项目类型：Godot 4 俯视角生存玩法原型
- 项目根目录：`F:\lingjiechuanshuo`
- Godot 版本：4.7.2 stable
- Godot 可执行文件：`F:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`
- 主场景：`res://main.tscn`
- 项目配置：`res://project.godot`

运行测试使用：

```powershell
& 'F:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' `
  --path 'F:\lingjiechuanshuo' `
  --headless --display-driver headless --audio-driver Dummy --quit-after 300
```

截至本文件创建时，主场景已通过上述无界面运行测试，玩家、GameManager、血条和修为条均成功初始化，进程退出码为 0。

## 当前架构

- `main.tscn`：当前实际使用的主场景。
- `player.gd`：WASD 移动、四方向动画、自动寻找最近敌人并发射火球、生命值和修为/境界系统。
- `enemy.gd`：敌人追踪、近战攻击、受伤反馈、死亡和灵气掉落。
- `fireball.gd`：火球移动、命中、伤害、分裂、高速、穿透和暴击 Buff。
- `game_manager.gd`：开始游戏、计时、刷怪、Buff 三选一、死亡和重开。
- `aura_drop.gd`：玩家拾取灵气。
- `status_bar.gd`：血条、修为条和境界文本 UI。
- `camera_2d.gd`：跟随玩家并限制地图边界。
- `damage_label.gd`：飘字伤害显示。
- `main.gd`：较早的刷怪逻辑遗留脚本；当前主场景使用 `GameManager`，修改刷怪流程时优先检查 `game_manager.gd`。

## 当前玩法功能

- 玩家自动锁定范围内最近敌人并发射火球。
- 敌人从屏幕边缘生成并追踪玩家。
- 敌人死亡掉落灵气，灵气累计后提升境界。
- 境界提升时出现三选一 Buff：分裂、高速、穿透、巨型火球/暴击。
- 支持开始游戏、计时、死亡界面和重新开始。

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
