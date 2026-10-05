# World Sim

Godot **4.7.2-stable (mono)** 的 2D 经济模拟工程。

## 运行

```powershell
$godot = 'D:\Godot\Godot_v4.7.2-stable_mono_win64_console.exe'

& $godot --path .                      # 跑游戏
& $godot --headless --path . --quit-after 120   # 无头自检
& $godot --headless --check-only --path . --script res://scripts/economy_system.gd
```

## 目录

| 路径 | 说明 |
|---|---|
| `scenes/worldsim.tscn` | 主场景 |
| `scripts/economy_system.gd` | `EconomySystemGodot`：账户、账本、宏观指标、季度 tick |
| `scripts/player_character.gd` | `PlayerCharacter`：四向移动（场景使用） |
| `scripts/player.gd` | `PlayerController`：与上者重复，未被引用 |
| `scripts/world_sim_hud.gd` | 宏观指标 HUD |
| `sim/baseline.gd` | `BaselineScript`：基线常量与 `load_config()` |
| `sim/config.json` | 基线数值 |
| `addons/godot_mcp/` | 第三方 MCP 插件（作者 LIDAXIAN，**已打补丁**） |

## 说明

进度、已修问题、未决问题、以及 Godot 4.7.2 那个会让插件瘫痪的引擎 bug，
都记在 [`HANDOFF.md`](HANDOFF.md) 里。
