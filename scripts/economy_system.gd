extends Node2D
class_name EconomySystemGodot

## 经济系统 Godot 实现 - 对应 backend/sim/economy.go
# 统一管理资金、账户、宏观变量，tick-based 季度推进

var _accounts: Dictionary = {}
var _ledger: Array = []
var _initial_money: int = 0
var _seq: int = 0

# 宏观经济状态 - 每个季度更新
var macro := {
	"gdp": 100.0,
	"inflation": 0.02,
	"base_rate": 5.0,
	"unemployment": 4.5,
	"price_index": 100.0,
	"pmi": 53.0,
}

# 季度周期状态机 - 对应 economy.go 的 cycle phase tracking
var _cycle_phase: String = "recovery"  # recovery | boom | recession | slowdown
var _quarter_in_cycle: int = 0  # 1-4 within current cycle

func _ready() -> void:
	print("EconomySystemGodot ready")

# 账户管理 - mirroring account.go API
func open_account(id: String, cash_minor: int = 0) -> Dictionary:
	var acc := {"cash_minor": cash_minor}
	_accounts[id] = acc
	_initial_money += cash_minor
	return acc

func get_account(id: String) -> Dictionary:
	if not _accounts.has(id):
		_accounts[id] = {}
	return _accounts.get(id, {})

# 统一资金入口 - 所有余额变动都落在账本上，支持金钱守恒核验
func add_money(id: String, delta: int, reason: String, field := "cash") -> int:
	if not _accounts.has(id):
		_accounts[id] = {}
	var acc: Dictionary = _accounts.get(id)
	var before: int = 0
	if field == "cash":
		before = int(acc.get("cash_minor", 0))
	var after: int = before + delta
	var applied: int = after - before
	acc["cash_minor"] = after
	_seq += 1
	_ledger.append({"account": id, "field": field, "delta": applied, "reason": reason, "seq": _seq})
	return applied

# 转账：现金对现金，总额不变
func transfer(from_id: String, to_id: String, amount: int) -> bool:
	if amount <= 0 or not get_account(from_id).has("cash_minor"):
		return false
	add_money(from_id, -amount, "transfer")
	add_money(to_id, amount, "transfer")
	return true

# 货币发行/回笼 - mirroring issue_money / burn_money
func issue_money(amount: int) -> void:
	add_money("central_bank", amount, "monetary_expansion", "cash")

func burn_money(amount: int) -> bool:
	if get_account("central_bank").get("cash_minor", 0) < amount:
		return false
	add_money("central_bank", -amount, "monetary_contraction", "cash")
	return true

# 季度 tick 推进宏观指标 - FULL IMPLEMENTATION of tick_macro()
func tick_macro() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	# RandomNumberGenerator 没有 randomize_seed()，用 seed 属性赋值。
	rng.seed = int(Time.get_unix_time_from_system())
	
	_advance_cycle(rng)
	
	# GDP growth follows business cycle phase
	var gdp_growth: float = _cycle_growth_rate()
	macro["gdp"] = float(macro.get("gdp", 100.0)) * (1.0 + gdp_growth)
	
	# Inflation via Taylor rule response to output gap, clamped to baseline bounds
	var inflation: float = _calculate_inflation(gdp_growth)
	macro["inflation"] = clampf(inflation, 0.005, 0.25)
	
	# Base rate responds to inflation (Taylor-style rule)
	macro["base_rate"] = _calculate_base_rate(inflation, gdp_growth)
	
	# Unemployment via Phillips curve relationship with growth
	var unemployment: float = _calculate_unemployment(gdp_growth)
	macro["unemployment"] = clampf(unemployment, 2.0, 15.0)
	
	# Price index compounds inflation (mirroring price_index * (1 + inflation))
	var price_index: float = float(macro.get("price_index", 100.0)) * (1.0 + inflation)
	macro["price_index"] = snappedf(price_index, 0.01)
	
	# PMI peaks in boom, bottoms in recession
	var pmi: float = _calculate_pmi()
	macro["pmi"] = clampf(pmi, 35.0, 75.0)
	
	return macro.duplicate(true)

func _advance_cycle(rng := RandomNumberGenerator.new()) -> void:
	# Quarter advances (1-4), cycle phase transitions deterministically with noise
	_quarter_in_cycle += 1
	
	if _quarter_in_cycle > 4:
		_quarter_in_cycle = 1
		_transition_to_next_phase(rng)

func _transition_to_next_phase(rng := RandomNumberGenerator.new()) -> void:
	var phases: Array[String] = ["recovery", "boom", "recession", "slowdown"]
	
	if _cycle_phase == "recovery":
		# Recovery -> boom after strong expansion (quarter 3 typically)
		if rng.randf() > 0.35:
			_cycle_phase = "boom"
	elif _cycle_phase == "boom":
		# Boom -> recession with probability proportional to overheating
		var overheat_prob: float = clampf((macro.get("gdp", 100.0) - 120.0) / 50.0, 0.0, 1.0)
		if rng.randf() < overheat_prob:
			_cycle_phase = "recession"
		else:
			_cycle_phase = "slowdown"
	elif _cycle_phase == "recession":
		# Recession -> slowdown as conditions stabilize (quarter 2 typically)
		if rng.randf() > 0.4:
			_cycle_phase = "slowdown"
	elif _cycle_phase == "slowdown":
		# Slowdown always transitions back to recovery
		_cycle_phase = "recovery"

func _cycle_growth_rate() -> float:
	var rates := {
		"recovery": 0.045,
		"boom": 0.065,
		"recession": -0.035,
		"slowdown": -0.01,
	}
	return float(rates.get(_cycle_phase, 0.02))

func _calculate_inflation(gdp_growth: float) -> float:
	# Higher growth initially dampens inflation (slack), but overheating spikes it
	var output_gap: float = gdp_growth - 0.025
	return base_inflation + output_gap * 1.5

func _calculate_base_rate(inflation: float, gdp_growth: float) -> float:
	# Taylor-style rule: raise rate when inflation > target or growth too low
	var target: float = 2.0
	var response_to_inflation: float = (inflation - target) * 4.0
	var response_to_output: float = maxf(0.0, gdp_growth - 0.03) * 5.0
	return maxf(0.0, float(macro.get("base_rate", 5.0)) + response_to_inflation + response_to_output)

func _calculate_unemployment(gdp_growth: float) -> float:
	# Inverse relationship with GDP growth (Okun's law simplified)
	var natural_rate: float = baseline_unemployment
	return natural_rate - gdp_growth * 8.0

func _calculate_pmi() -> float:
	# PMI peaks in boom, bottoms in recession, pmi_base centered at expansion
	var phase_offset: float = 0.0
	if _cycle_phase == "boom":
		phase_offset = 25.0
	elif _cycle_phase == "recession":
		phase_offset = -25.0
	else:
		phase_offset = _cycle_growth_rate() * 400.0
	return clampf(pmi_base + phase_offset, 35.0, 75.0)

func is_conserved() -> bool:
	# Verify money conservation across all accounts
	var total_current: int = 0
	for id in _accounts.keys():
		var acc: Dictionary = _accounts.get(id)
		if acc.has("cash_minor"):
			total_current += int(acc["cash_minor"])
	return total_current == _initial_money

func ledger() -> Array:
	return _ledger.duplicate(true)

# Baseline constants from baseline.gd for clamping/validation
var base_inflation: float = 0.015
var baseline_unemployment: float = 4.5
var pmi_base: float = 53.0
var quarters_per_year: int = 4
