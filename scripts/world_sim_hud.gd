extends Label

## 宏观指标 HUD。
## 默认通过分组 "economy_system" 找到经济系统；也可以用 economy_path 直接指定。

@export var economy_path: NodePath = ^""

## 刷新间隔（秒），避免每帧都重建字符串。
@export var refresh_interval: float = 0.25

var _economy: EconomySystemGodot
var _elapsed: float = 0.0


func _ready() -> void:
	_economy = _find_economy()
	if _economy == null:
		text = "经济系统未连接"
		return
	_refresh()


func _process(delta: float) -> void:
	if _economy == null:
		return
	_elapsed += delta
	if _elapsed < refresh_interval:
		return
	_elapsed = 0.0
	_refresh()


func _find_economy() -> EconomySystemGodot:
	if not economy_path.is_empty():
		return get_node_or_null(economy_path) as EconomySystemGodot
	return get_tree().get_first_node_in_group(&"economy_system") as EconomySystemGodot


func _refresh() -> void:
	var macro: Dictionary = _economy.macro
	text = "GDP %.1f ｜ 通胀 %.2f%% ｜ 基准利率 %.2f%% ｜ 失业率 %.1f%% ｜ 物价指数 %.1f ｜ PMI %.1f" % [
		float(macro.get("gdp", 0.0)),
		float(macro.get("inflation", 0.0)) * 100.0,
		float(macro.get("base_rate", 0.0)),
		float(macro.get("unemployment", 0.0)),
		float(macro.get("price_index", 0.0)),
		float(macro.get("pmi", 0.0)),
	]
