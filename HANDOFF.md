# 交接说明

> 工程：`D:\世界\世界`（`config/name="World Sim"`）
> 引擎：Godot **4.7.2-stable mono** — `D:\Godot\Godot_v4.7.2-stable_mono_win64(_console).exe`
> 整理时间：2026-10-05

---

## 1. 这是什么

一个 2D 经济模拟工程，主场景 `res://scenes/worldsim.tscn`。

⚠️ `README.md` 里写的 `backend/`、`client/`、`shared/`、`scripts/setup-engine.sh`
**在本仓库都不存在**，那段说明是从其它工程抄来的，别照着找。

## 2. 目录结构

```
project.godot                     主场景 = res://scenes/worldsim.tscn
                                  启用插件 = res://addons/godot_mcp/plugin.cfg
                                  物理 = Jolt Physics，渲染驱动 = d3d12
scenes/worldsim.tscn              主场景
scripts/economy_system.gd         EconomySystemGodot —— 账户 / 账本 / 宏观指标 / 季度 tick
scripts/player_character.gd       PlayerCharacter —— 四向移动（场景实际用的就是这个）
scripts/player.gd                 PlayerController —— 与上面几乎逐行重复，未被任何场景引用
scripts/world_sim_hud.gd          宏观指标 HUD（按分组 "economy_system" 找经济系统）
sim/baseline.gd                   BaselineScript —— 基线常量 + load_config()
sim/config.json                   基线数值（gdp_growth / base_inflation / ...）
addons/godot_mcp/                 第三方 MCP 插件（作者 LIDAXIAN），已被打过补丁 —— 见第 4 节
```

场景树：

```
WorldSim (Node2D)
├── EconomySystem (Node2D, group=economy_system)   ← economy_system.gd
├── Player (CharacterBody2D)                        ← player_character.gd
│   ├── Body (Polygon2D 32x32)
│   ├── CollisionShape2D (RectangleShape2D 32x32)
│   └── Camera2D
└── HUD (CanvasLayer)
    └── MacroPanel (PanelContainer)
        └── MacroLabel (Label)                      ← world_sim_hud.gd
```

## 3. 怎么跑

```powershell
$godot = 'D:\Godot\Godot_v4.7.2-stable_mono_win64_console.exe'

# 跑游戏
& $godot --path 'D:\世界\世界'

# 无头跑（CI / 快速自检）
& $godot --headless --path 'D:\世界\世界' --quit-after 120

# 无头开编辑器（会启动 godot_mcp 的 HTTP 服务，注意 3000 端口占用）
& $godot --headless --editor --path 'D:\世界\世界' --quit

# 单文件语法检查
& $godot --headless --check-only --path 'D:\世界\世界' --script res://scripts/economy_system.gd
```

预期输出：`EconomySystemGodot ready` / `PlayerCharacter ready`，退出码 0。

## 4. 本轮修过什么

### 4.1 `addons/godot_mcp` 启动时序（真 bug）

`plugin.gd:70` 在 `_enter_tree()` 里就调 `mcp_server.start()`，而 `_tcp_server` 原先在
`mcp_server.gd` 的 `_ready()` 里才创建 —— 子节点的 `_ready()` 此时还没跑，于是
`Cannot call method 'listen' on a null value`，MCP 服务端从未监听。

**改法**：`TCPServer.new()` 移进 `_init()`；`_ready()` 只留 `_register_tools()`；`start()` 加惰性兜底。

### 4.2 Godot 4.7.2 引擎 bug：`EditorInterface` 类型注解会让 GDScript VM 崩溃

**症状**：插件能起来、74 个工具都注册了，但所有依赖编辑器的工具都返回
`Editor interface not available` / `No scene currently open`（编辑器里明明开着场景）。

**根因**（已用最小复现定位）：

| 写法 | 结果 |
|---|---|
| `Engine.has_singleton("EditorInterface")` | ✅ `true` |
| `var o: Object = Engine.get_singleton("EditorInterface")` | ✅ 正常 |
| `var n: Node = <Variant>` | ✅ 正常 |
| `var ei: EditorInterface = Engine.get_singleton("EditorInterface")` | 💥 `Internal script error! Opcode: 28` |
| 函数标注 `-> EditorInterface` 后 `return Engine.get_singleton(...)` | 💥 `Opcode: 68` / `31` |

即：**在 4.7.2 里把值赋给「类型标注为 `EditorInterface`」的变量或返回值，GDScript 虚拟机会内部报错，
函数静默返回 `null`**。这是引擎 bug，不是插件的逻辑错。

**改法**：把插件里 14 处 `EditorInterface` 类型注解全部去掉（改成动态类型）：

- `addons/godot_mcp/tools/base_tools.gd:364` —— `_get_editor_interface()` 去掉返回类型注解
- `addons/godot_mcp/tools/editor_tools.gd` —— 13 处 `ei: EditorInterface` → `ei`

> ⚠️ **改动 .gd 文件后必须重启 Godot 编辑器，或在「项目 → 项目设置 → 插件」里把 `godot_mcp`
> 取消勾选再勾上。** 光改磁盘文件不生效：插件虽会热重载脚本，但已经 new 出来的 RefCounted
> 工具对象仍绑着旧函数体。

### 4.3 脚本里既有的解析/运行错误

`scripts/` 下的脚本此前**从未编译通过**，逐个剥出来修掉：

| 文件:行 | 问题 | 修法 |
|---|---|---|
| `player.gd:21` | `-> :` 缺返回类型 | `-> void:` |
| `economy_system.gd:31` | `{cash_minor}` 少了 key/value | `{"cash_minor": cash_minor}` |
| `economy_system.gd:53` | 裸标识符当字典 key | 4 个 key 补引号 |
| `economy_system.gd:77` | `RandomNumberGenerator` 没有 `randomize_seed()` | `rng.seed = ...` |
| `economy_system.gd:97` | `roundi(x, 2)` 多传参 | `snappedf(price_index, 0.01)` |
| `economy_system.gd:154` | `base_rate` 未声明 | `float(macro.get("base_rate", 5.0))` |
| `economy_system.gd:163` | C 风格三元 `?:`（GDScript 无此语法） | 改 `if/elif/else` |
| `economy_system.gd:45,177` | `:=` 从 Variant 推断（该工程视作错误） | 显式 `: Dictionary` |
| `player.gd` / `player_character.gd` | `_physics_process` 只算 `velocity` 从不应用，角色不会动 | 补 `move_and_slide()` |

### 4.4 结构清理

- `scenes/main.tscn` 与 `sim/baseline.gd` 原本是**空目录**（不是文件），已删除
- `scenes/worldsim.tscn` 新建（原 `run/main_scene` 指向它但文件不存在，编辑器启动即报错）
- `scripts/world_sim_hud.gd` 新建
- `sim/baseline.gd` 重写为真的 `BaselineScript`

## 5. 未决问题（都没动，需要你拍板）

1. **`_calculate_base_rate` 单位不一致** —— `inflation` 全程是小数（0.045 = 4.5%），
   但函数里 `target = 2.0` 当百分比用，导致 `response_to_inflation = -7.82`，
   基准利率被 `maxf(0.0, ...)` 压成 **0**。实测结果就是 `base_rate = 0.0`。
   看着应改成 `0.02`，但不确定后端 Go 那边的约定。
2. **基线常量打架** —— `economy_system.gd` 自带 `baseline_unemployment = 4.5`、`pmi_base = 53.0`，
   与 `sim/config.json` 的 `0.04`、`55.0` 不一致。`sim/baseline.gd` 以 config.json 为准，
   但**没有**去改 `economy_system.gd` 的取值（那会改变游戏行为）。
3. **`open_account` 不幂等** —— 重复调用会重置账户余额却又累加 `_initial_money`，
   `is_conserved()` 随即变 false。
4. **`player.gd`（PlayerController）疑似误建的副本**，与 `player_character.gd` 几乎逐行相同，
   未被任何场景引用。删或留由你定。
5. **`group_group` 工具 schema 与实现不符** —— schema 里 `required` 只有 `action`，
   但实现要求必须传 `path`，否则报 `Path is required`。

## 6. git 状态

```
origin   = git@github-youxi:3uejz/youxi.git
本地分支 = main
历史     = 8ba7405 Initial commit  →  b30472f chore: 工程整理与首轮修复
           （原仓库自带的 Initial commit 保留为祖先，没有覆盖任何提交）
推送     = 快进即可，不需要 force
```

### 仓库澄清（重要，别再搞混）

| 仓库 | 内容 |
|---|---|
| `3uejz/youxi` | **本工程**（World Sim）。原本只有一个占位 README |
| `3uejz/-` | **浮生录** —— 是另一个工程 `D:\git\my-project` 的 origin |
| `3uejz/godot` | Godot 引擎 fork（给 `engine-modules` overlay 用） |
| Gitea `192.168.31.250:3000/suiyuya/youxi` | 旧 origin，内容是浮生录；**该服务器目前连不上** |

> ⚠️ 曾经差点把本工程 force push 到 `3uejz/-`，那会覆盖掉浮生录在 GitHub 上的仓库。已叫停。

### 推送

```powershell
git push -u origin main
```

走 `~/.ssh/id_ed25519_youxi`（`~/.ssh/config` 里的 `Host github-youxi` 别名）。
因为原有的 `~/.ssh/id_ed25519` 是 `3uejz/-` 的 deploy key，对 `youxi` 没有写权限，
而同一个公钥不能挂到第二个仓库（GitHub 报 Key already in use）。

> HTTPS 直连 `github.com` 在本机返回 `Empty reply from server`（网络原因），
> 所以全局 git config 配了 `url.https://gh-proxy.com/https://github.com/.insteadOf`，读操作走代理。
> **gh-proxy 不支持 push**，别指望它。

## 7. 怎么复验

```powershell
$godot = 'D:\Godot\Godot_v4.7.2-stable_mono_win64_console.exe'
foreach ($f in 'res://scripts/player.gd','res://scripts/player_character.gd',
               'res://scripts/economy_system.gd','res://scripts/world_sim_hud.gd',
               'res://sim/baseline.gd') {
    & $godot --headless --check-only --path 'D:\世界\世界' --script $f
}
& $godot --headless --path 'D:\世界\世界' --quit-after 120      # 期望 exit=0
```

MCP 工具实测（编辑器开着时）：

```powershell
$body = '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
(Invoke-WebRequest 'http://127.0.0.1:3000/mcp' -Method Post `
    -ContentType 'application/json' -Body $body -UseBasicParsing).Content
# 期望：result.tools 共 74 个
```

> 注意：本机 **3000 端口被占用**（godot_mcp 插件的 HTTP 服务，也是上面那个 `origin` 的端口号来源之一，
> 两者无关）。`origin` 那台是 `192.168.31.250`，不冲突。
