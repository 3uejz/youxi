extends RefCounted
class_name BaselineScript

## 游戏基线参数。
## 数值与 sim/config.json 保持一致；改动任意一侧时请同步另一侧。

const GDP_GROWTH: float = 0.025
const BASE_INFLATION: float = 0.015
const UNEMPLOYMENT_RATE: float = 0.04
const PMI_BASE: float = 55.0
const QUARTERS_PER_YEAR: int = 4

const CONFIG_PATH: String = "res://sim/config.json"


## 返回基线字典：优先读 sim/config.json，缺失或损坏时回退到上面的常量。
static func load_config() -> Dictionary:
	var config: Dictionary = {
		"gdp_growth": GDP_GROWTH,
		"base_inflation": BASE_INFLATION,
		"unemployment_rate": UNEMPLOYMENT_RATE,
		"pmi_base": PMI_BASE,
		"quarters_per_year": QUARTERS_PER_YEAR,
	}

	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("BaselineScript: 找不到 %s，改用内置常量。" % CONFIG_PATH)
		return config

	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_warning("BaselineScript: 打不开 %s，改用内置常量。" % CONFIG_PATH)
		return config

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if parsed is Dictionary:
		config.merge(parsed as Dictionary, true)
	else:
		push_warning("BaselineScript: %s 解析失败，改用内置常量。" % CONFIG_PATH)

	return config
