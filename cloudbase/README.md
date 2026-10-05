# 除魔务尽联网原型

环境：`chumowujin-beta-d0faxqcq5b2c32fa`，上海，CloudBase PostgreSQL。

## 运行

```powershell
& 'F:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path 'F:\lingjiechuanshuo' res://network/online_test.tscn
```

使用控制台中创建的普通测试账号登录，输入角色名字创建角色，领取修为，退出再登录验证存档。当前不支持客户端注册、找回密码或持久登录；令牌过期后需要重新登录。账号密码和令牌只保存在运行内存，不写入文件。

`network/cloudbase_config.json` 只有环境 ID 和公开 publishable key，不包含服务端 API Key。后台管理凭证和自动回归测试账号均位于被 Git 忽略的路径。

## 服务器规则

- `cultivation_characters` 每个用户一行，RLS 只允许读取自己的角色。
- 客户端无 INSERT、UPDATE、DELETE 权限，角色通过 RPC 创建，重复创建返回已有角色。
- `claim_cultivation` 使用服务器时间，每分钟 1 点，最多结算 12 小时；这是内测参数。
- 使用行锁串行结算，保留不足一分钟的时间，避免重复领奖。
- 当前没有突破、背包、副本奖励或实时多人功能。
- 迁移版本：`20261005173000_create_cultivation_characters`。

## 回归

准备被 Git 忽略的 JSON 文件，字段为 `username` 和 `password`，不在命令或日志中打印密码。

```powershell
$env:CHUMOWUJIN_TEST_ACCOUNT='F:\lingjiechuanshuo\.tmp\cloudbase-test-account.json'
& 'F:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path 'F:\lingjiechuanshuo' --headless --audio-driver Dummy --script res://tests/cloudbase_online.gd
```

成功输出 `CLOUDBASE_TEST_RESULT failures=0`，进程退出码 0。自动验证账号仅用于内测，凭证不提交 Git。

## 发布边界

当前联网入口是桌面测试场景。离线主菜单不调用网络，Android 导出仍关闭联网权限并排除联网测试资源。尚未重新打包或发布联网 APK。

接入正式 Android 主界面之前，需提供游戏内与网页一致的新版隐私政策、账号管理和退出／删除流程，再开启 INTERNET 权限并进行手机实测。现有公开隐私政策描述的是已提交的离线版本，不能直接用于未来联网版本。
