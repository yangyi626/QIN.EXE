class_name GameCore
extends RefCounted
## 《大秦：2076》纯逻辑核心层（v2.1）
## 严禁引用任何 Node、场景树或 UI 节点；UI 仅订阅下方信号并调用公开命令方法。

signal state_changed(snapshot: Dictionary)
signal strike_performed(region_id: String, damage: int, source: String, conquered: bool)
signal event_triggered(event_data: Dictionary)
signal advisor_spoke(advisor_id: String, advisor_name: String, line: String)
signal hidden_triggered(hidden_id: String, reward_text: String)
signal game_ended(ending_code: String, ending_data: Dictionary)

var _data: Dictionary = {}
var _lines: Dictionary = {}
var _rng := RandomNumberGenerator.new()

var mvp_only: bool = false
var turn: int = 1
var patience: int = 12
var morale: int = 60
var actions_left: int = 2
var attack_left: int = 1
var refreshes_left: int = 3
var free_hook_available: bool = true

var regions: Array[Dictionary] = []
var advisors: Array[Dictionary] = []
var terminal_cards: Array[Dictionary] = []
var bought_one_time: Dictionary = {}

var sea_unlocked: bool = false
var cement_road_bonus: int = 0
var ak47_bonus: int = 0
var penicillin_turn: bool = false
var education_turn: bool = false
var overheat_no_refresh: bool = false
var overheat_power_debuff: int = 0
var _clear_overheat_next: bool = false
var next_turn_action_penalty: int = 0

var cyber_burn_turns: int = 0
var loan_queue: Array[int] = []

var hidden_state: Dictionary = {
	"penglai": {"found": false, "used": false},
	"dazexiang": {"found": false, "used": false},
	"antarctica": {"found": false, "used": false},
}

var pending_event: Dictionary = {}
var game_over_code: String = ""
var logs: Array[String] = []


func init_game(game_data: Dictionary, lines_data: Dictionary = {}, p_mvp_only: bool = false, rng_seed: int = -1) -> void:
	_data = game_data.duplicate(true)
	_lines = lines_data.duplicate(true)
	mvp_only = p_mvp_only
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

	var c: Dictionary = _data.get("constants", {})
	turn = 1
	patience = int(c.get("initial_patience", 12))
	morale = int(c.get("initial_morale", 60))
	actions_left = int(c.get("actions_per_turn", 2))
	attack_left = int(c.get("attacks_per_turn", 1))
	refreshes_left = int(c.get("refreshes_per_turn", 3))
	free_hook_available = true

	regions.clear()
	for r in _data.get("regions", []):
		var copy: Dictionary = r.duplicate(true)
		copy["max_hp"] = int(r["hp"])
		copy["hp"] = int(r["hp"])
		copy["conquered"] = false
		regions.append(copy)

	advisors.clear()
	terminal_cards.clear()
	bought_one_time.clear()

	sea_unlocked = false
	cement_road_bonus = 0
	ak47_bonus = 0
	penicillin_turn = false
	education_turn = false
	overheat_no_refresh = false
	overheat_power_debuff = 0
	_clear_overheat_next = false
	next_turn_action_penalty = 0
	cyber_burn_turns = 0
	loan_queue.clear()

	hidden_state = {
		"penglai": {"found": false, "used": false},
		"dazexiang": {"found": false, "used": false},
		"antarctica": {"found": false, "used": false},
	}
	pending_event = {}
	game_over_code = ""
	logs.clear()

	_log("公元前221年，你携带未来终端坠落咸阳宫。12回合内一统寰宇，成则万世国师，败则斩首。")
	_roll_terminal(true)
	_emit_state()


func has_advisor(advisor_id: String) -> bool:
	for a in advisors:
		if a["id"] == advisor_id:
			return true
	return false


func get_morale_cap() -> int:
	return 80 if has_advisor("shangyang") else 100


func get_conquered_count() -> int:
	var count := 0
	for r in regions:
		if r["conquered"]:
			count += 1
	return count


func get_act() -> int:
	var c := get_conquered_count()
	if c <= 1:
		return 1
	if c <= 3:
		return 2
	return 3


func get_conventional_power() -> int:
	var base := 20 + cement_road_bonus + ak47_bonus - overheat_power_debuff
	if has_advisor("shangyang"):
		base *= 2
	return maxi(0, base)


func get_effective_cheat_delta(cheat: Dictionary) -> int:
	var delta := int(cheat["morale_delta"])
	if delta >= 0:
		if cheat["category"] == "livelihood" and has_advisor("libing"):
			return delta * 2
		return delta
	if turn == 1 and free_hook_available and cheat["id"] == "drone":
		return 0
	var cost := float(absi(delta))
	var mult := 1.0
	if cheat["category"] == "military" and has_advisor("zhugeliang"):
		mult *= 0.5
	if has_advisor("wanganshi"):
		mult *= 0.8
	# v2.1 规定：诸葛亮与王安石同场时 ×0.5 ×0.8 只在最后向上取整一次
	var final_cost := int(ceil(cost * mult))
	if cheat["category"] == "military" and has_advisor("caocao"):
		final_cost += 10
	return -final_cost


func get_effective_advisor_cost(adv: Dictionary) -> int:
	if turn == 1 and free_hook_available:
		return 0
	return int(adv["cost"])


func get_fleet_cost() -> int:
	return 15 if has_advisor("tanghe") else 30


func get_refresh_cost() -> int:
	return 0 if has_advisor("wanganshi") else 5


func can_attack_region(region_id: String) -> bool:
	var r := _find_region(region_id)
	if r.is_empty() or r["conquered"]:
		return false
	if r.get("requires_sea", false):
		return sea_unlocked
	var pre: String = r.get("prereq", "")
	if pre == "":
		return true
	var pre_r := _find_region(pre)
	return not pre_r.is_empty() and bool(pre_r["conquered"])


func is_hidden_visible(hidden_id: String) -> bool:
	if not hidden_state.has(hidden_id):
		return false
	if hidden_state[hidden_id]["used"]:
		return false
	if hidden_id == "dazexiang":
		return bool(hidden_state["dazexiang"]["found"])
	if mvp_only:
		return false
	return morale < 50


func get_snapshot() -> Dictionary:
	return {
		"turn": turn,
		"patience": patience,
		"morale": morale,
		"morale_cap": get_morale_cap(),
		"actions_left": actions_left,
		"attack_left": attack_left,
		"refreshes_left": refreshes_left,
		"free_hook_available": free_hook_available,
		"conquered_count": get_conquered_count(),
		"act": get_act(),
		"conventional_power": get_conventional_power(),
		"sea_unlocked": sea_unlocked,
		"penicillin_turn": penicillin_turn,
		"education_turn": education_turn,
		"cyber_burn_turns": cyber_burn_turns,
		"loan_remaining": loan_queue.size(),
		"overheat_no_refresh": overheat_no_refresh,
		"regions": regions.duplicate(true),
		"advisors": advisors.duplicate(true),
		"terminal_cards": terminal_cards.duplicate(true),
		"hidden_visible": {
			"penglai": is_hidden_visible("penglai"),
			"dazexiang": is_hidden_visible("dazexiang"),
			"antarctica": is_hidden_visible("antarctica"),
		},
		"pending_event": pending_event.duplicate(true),
		"game_over_code": game_over_code,
		"logs": logs.duplicate(),
	}


func conventional_attack(region_id: String) -> Dictionary:
	if game_over_code != "" or not pending_event.is_empty():
		return {"ok": false, "error": "当前状态不可进攻"}
	if attack_left <= 0:
		return {"ok": false, "error": "本回合常规进攻次数已用完"}
	if education_turn:
		return {"ok": false, "error": "本回合已购买义务教育，无法常规进攻"}
	if not can_attack_region(region_id):
		return {"ok": false, "error": "该板块未打通前置或已占领"}

	var r := _find_region(region_id)
	var eff: float = 1.0 if (region_id == "south_asia" and penicillin_turn) else float(r["efficiency"])
	var dmg := int(floor(float(get_conventional_power()) * eff))
	attack_left = 0
	var res := _apply_damage(region_id, dmg, false, "常规秦军")
	_emit_state()
	return res


func build_fleet() -> Dictionary:
	if game_over_code != "" or not pending_event.is_empty():
		return {"ok": false, "error": "当前状态不可造船"}
	if sea_unlocked:
		return {"ok": false, "error": "渡海航线已打通"}
	if actions_left <= 0:
		return {"ok": false, "error": "本回合行动点已用完"}

	var cost := get_fleet_cost()
	actions_left -= 1
	sea_unlocked = true
	_modify_morale(-cost, "强征造楼船", false)
	_log("强征民夫造楼船渡海（-%d 民心），未知新大陆已开放。" % cost)
	_emit_state()
	return {"ok": true, "cost": cost}


func refresh_terminal() -> Dictionary:
	if game_over_code != "" or not pending_event.is_empty():
		return {"ok": false, "error": "当前状态不可刷新"}
	if overheat_no_refresh:
		return {"ok": false, "error": "终端降频运行中，本回合无法刷新"}
	if refreshes_left <= 0:
		return {"ok": false, "error": "本回合刷新次数已用完"}

	var cost := get_refresh_cost()
	refreshes_left -= 1
	if cost > 0:
		_modify_morale(-cost, "刷新终端", false)
	if game_over_code == "":
		_roll_terminal(false)
		_log("终端刷新完成（%s）。" % ("免费" if cost == 0 else "-%d 民心" % cost))
	_emit_state()
	return {"ok": true, "cost": cost}


func summon_advisor(slot_index: int, replace_index: int = -1) -> Dictionary:
	if game_over_code != "" or not pending_event.is_empty():
		return {"ok": false, "error": "当前状态不可召唤"}
	if actions_left <= 0:
		return {"ok": false, "error": "本回合行动点已用完"}
	if slot_index < 0 or slot_index >= terminal_cards.size():
		return {"ok": false, "error": "卡槽越界"}
	var card: Dictionary = terminal_cards[slot_index]
	if card["bought"] or card["kind"] != "advisor":
		return {"ok": false, "error": "该卡不是可召唤名臣"}
	if advisors.size() >= 2 and (replace_index < 0 or replace_index >= 2):
		return {"ok": false, "error": "槽位已满，需指定替换位置", "need_replace": true}

	var adv: Dictionary = card["data"]
	var cost := get_effective_advisor_cost(adv)
	if turn == 1 and free_hook_available:
		free_hook_available = false

	actions_left -= 1
	card["bought"] = true
	if cost > 0:
		_modify_morale(-cost, "召唤%s" % adv["name"], false)
	if game_over_code != "":
		_emit_state()
		return {"ok": true}

	if advisors.size() >= 2:
		advisors[replace_index] = adv.duplicate(true)
	else:
		advisors.append(adv.duplicate(true))

	if adv["id"] == "shangyang" and morale > 80:
		morale = 80

	var line := _get_advisor_line(adv["id"], "summon")
	_log("召唤 AI 名臣【%s】：%s" % [adv["name"], line])
	advisor_spoke.emit(adv["id"], adv["name"], line)
	_emit_state()
	return {"ok": true, "advisor_id": adv["id"], "cost": cost}


func buy_cheat(slot_index: int, target_region_id: String = "") -> Dictionary:
	if game_over_code != "" or not pending_event.is_empty():
		return {"ok": false, "error": "当前状态不可购买"}
	if actions_left <= 0:
		return {"ok": false, "error": "本回合行动点已用完"}
	if slot_index < 0 or slot_index >= terminal_cards.size():
		return {"ok": false, "error": "卡槽越界"}
	var card: Dictionary = terminal_cards[slot_index]
	if card["bought"] or card["kind"] != "cheat":
		return {"ok": false, "error": "该卡不是可购买外挂"}

	var cheat: Dictionary = card["data"]
	if cheat["id"] == "education" and attack_left <= 0:
		return {"ok": false, "error": "本回合已常规进攻，不可购买义务教育"}
	if cheat["needs_target"]:
		var tr := _find_region(target_region_id)
		if tr.is_empty() or tr["conquered"]:
			return {"ok": false, "error": "需要指定一个未占领的目标板块"}

	var eff_delta := get_effective_cheat_delta(cheat)
	if turn == 1 and free_hook_available and cheat["id"] == "drone":
		free_hook_available = false

	actions_left -= 1
	card["bought"] = true
	if cheat["one_time"]:
		bought_one_time[cheat["id"]] = true

	if eff_delta != 0:
		_modify_morale(eff_delta, cheat["name"], false)
	if game_over_code != "":
		_emit_state()
		return {"ok": true, "cheat_id": cheat["id"]}

	var cao_mult := 2 if (cheat["category"] == "military" and has_advisor("caocao")) else 1
	var strike_res: Dictionary = {}

	match cheat["id"]:
		"rice":
			_log("【杂交水稻】落盘，民心 +%d。" % eff_delta)
		"penicillin":
			penicillin_turn = true
			_log("【青霉素】生效，本回合南亚与大洋常规效率恢复 1.00。")
		"cement_road":
			cement_road_bonus += 10
			_log("【水泥直道】贯通，常规秦军永久 +10。")
		"education":
			education_turn = true
			_log("【义务教育】推行，本回合无法常规进攻。")
		"drone":
			var instant := has_advisor("huoqubing")
			strike_res = _apply_damage(target_region_id, int(cheat["damage"]) * cao_mult, instant, "无人机蜂群")
		"artillery":
			strike_res = _apply_damage(target_region_id, int(cheat["damage"]) * cao_mult, false, "卫星制导重炮")
		"ak47":
			ak47_bonus += 30 * cao_mult
			_log("【AK-47 兵马俑】列装，常规秦军永久 +%d。" % (30 * cao_mult))
		"ironclad":
			sea_unlocked = true
			strike_res = _apply_damage(target_region_id, int(cheat["damage"]) * cao_mult, false, "跨海铁甲舰")
		"cyber_burn":
			cyber_burn_turns = 2
			_log("【赛博焚书】生效 2 回合，结束时反噬 -35 民心。")
		"holo_emperor":
			patience += 3
			_log("【全息假始皇】坐镇，始皇耐心 +3 回合。")
		"time_loan":
			loan_queue.append_array([15, 15, 15])
			_log("【跨时空贷款】+40 民心，未来 3 回合每回合扣 15。")
		"nuke_seal":
			strike_res = _apply_damage(target_region_id, 999, true, "核聚变传国玉玺")

	_emit_state()
	return {"ok": true, "cheat_id": cheat["id"], "morale_delta": eff_delta, "strike": strike_res}


func trigger_hidden(hidden_id: String) -> Dictionary:
	if game_over_code != "" or not pending_event.is_empty():
		return {"ok": false, "error": "当前状态不可触发隐藏关"}
	if not is_hidden_visible(hidden_id):
		return {"ok": false, "error": "该隐藏关尚未显现或已触发"}

	match hidden_id:
		"penglai":
			if actions_left <= 0:
				return {"ok": false, "error": "行动点不足"}
			actions_left -= 1
			hidden_state["penglai"]["used"] = true
			patience = maxi(1, patience - 1)
			_modify_morale(35, "蓬莱仙岛", false)
			hidden_triggered.emit("penglai", "民心 +35，耐心 -1")
		"dazexiang":
			if actions_left <= 0:
				return {"ok": false, "error": "行动点不足"}
			if advisors.is_empty():
				return {"ok": false, "error": "需要场上至少有 1 位在场名臣"}
			actions_left -= 1
			hidden_state["dazexiang"]["used"] = true
			_modify_morale(25, "大泽乡暗流", false)
			hidden_triggered.emit("dazexiang", "名臣微服安抚，民心 +25")
		"antarctica":
			if overheat_no_refresh or refreshes_left <= 0:
				return {"ok": false, "error": "本回合刷新次数不足"}
			refreshes_left -= 1
			hidden_state["antarctica"]["used"] = true
			_modify_morale(50, "南极时间舱", false)
			hidden_triggered.emit("antarctica", "不耗行动，民心 +50")
		_:
			return {"ok": false, "error": "未知隐藏关"}

	_emit_state()
	return {"ok": true, "hidden_id": hidden_id}


func end_turn() -> Dictionary:
	if game_over_code != "" or not pending_event.is_empty():
		return {"ok": false, "error": "当前无法结束回合"}

	if cyber_burn_turns > 0:
		cyber_burn_turns -= 1
		if cyber_burn_turns == 0:
			_log("【赛博焚书】反噬爆发：民心 -35！")
			_modify_morale(-35, "赛博焚书反噬", true)
			if game_over_code != "":
				_emit_state()
				return {"ok": true}

	if turn % 3 == 0 and patience > 1:
		var evs: Array = _data.get("events", [])
		if not evs.is_empty():
			pending_event = evs[_rng.randi_range(0, evs.size() - 1)].duplicate(true)
			event_triggered.emit(pending_event)
			_emit_state()
			return {"ok": true, "event": pending_event}

	_advance_to_next_turn()
	_emit_state()
	return {"ok": true}


func resolve_event(choice: String) -> Dictionary:
	if pending_event.is_empty():
		return {"ok": false, "error": "当前没有待处理事件"}
	var ev := pending_event
	pending_event = {}
	var loss := 5 if has_advisor("tanghe") else 10

	if choice == "A":
		_modify_morale(-loss, ev["title"], false)
	elif choice == "B":
		var b: Dictionary = ev["option_b"]
		match b["type"]:
			"action_penalty":
				next_turn_action_penalty += int(b["amount"])
			"disable_refresh_and_debuff":
				overheat_no_refresh = true
				overheat_power_debuff = int(b["power_debuff"])
			"buff_random_region":
				var targets := _unconquered_regions()
				if not targets.is_empty():
					var t: Dictionary = targets[_rng.randi_range(0, targets.size() - 1)]
					t["hp"] = int(t["hp"]) + int(b["hp_add"])
					t["max_hp"] = maxi(int(t["max_hp"]), int(t["hp"]))
	else:
		return {"ok": false, "error": "无效选项"}

	if game_over_code == "":
		_advance_to_next_turn()
	_emit_state()
	return {"ok": true}


# --- 确定性测试辅助方法（供 tests/ 使用） ---
func set_terminal_cards_for_test(cards: Array) -> void:
	terminal_cards.clear()
	for item in cards:
		var c: Dictionary = item.duplicate(true)
		c["bought"] = false
		terminal_cards.append(c)


func force_morale_for_test(value: int) -> void:
	morale = clampi(value, 0, get_morale_cap())
	if morale < 40:
		hidden_state["dazexiang"]["found"] = true
	if morale < 50 and not mvp_only:
		hidden_state["penglai"]["found"] = true
		hidden_state["antarctica"]["found"] = true


func force_region_conquered_for_test(region_id: String) -> void:
	var r := _find_region(region_id)
	if not r.is_empty():
		r["hp"] = 0
		r["conquered"] = true


# --- 内部结算逻辑 ---
func _advance_to_next_turn() -> void:
	turn += 1
	patience -= 1
	if patience <= 0:
		_trigger_ending("lose_time")
		return

	actions_left = maxi(0, 2 - next_turn_action_penalty)
	next_turn_action_penalty = 0
	attack_left = 1
	refreshes_left = 0 if overheat_no_refresh else 3
	penicillin_turn = false
	education_turn = false
	free_hook_available = false

	# v2.1 固定回合开始结算顺序：1.丝路 -> 2.贷款 -> 3.韩信 -> 4.刷新终端
	var west := _find_region("west")
	if not west.is_empty() and west["conquered"]:
		_modify_morale(5, "丝绸之路红利", false)

	if not loan_queue.is_empty():
		var due: int = loan_queue.pop_front()
		_modify_morale(-due, "跨时空贷款", false)
		if game_over_code != "":
			return

	if has_advisor("hanxin"):
		var targets := _unconquered_regions()
		if not targets.is_empty():
			var t: Dictionary = targets[_rng.randi_range(0, targets.size() - 1)]
			_apply_damage(t["id"], 25, false, "韩信自动打击")
			if game_over_code != "":
				return

	_roll_terminal(false)

	if overheat_no_refresh:
		_clear_overheat_next = true
	elif _clear_overheat_next:
		overheat_no_refresh = false
		overheat_power_debuff = 0
		_clear_overheat_next = false

	if not advisors.is_empty():
		var sp: Dictionary = advisors[_rng.randi_range(0, advisors.size() - 1)]
		var bucket := "hidden_hint" if (morale < 40 and is_hidden_visible("dazexiang")) else ("low_morale" if morale < 45 else "normal")
		var line := _get_advisor_line(sp["id"], bucket)
		advisor_spoke.emit(sp["id"], sp["name"], line)


func _roll_terminal(is_first_turn: bool) -> void:
	var pool: Array[Dictionary] = []
	for a in _data.get("advisors", []):
		if mvp_only and not bool(a.get("mvp", false)):
			continue
		if not has_advisor(a["id"]):
			pool.append({"kind": "advisor", "data": a.duplicate(true)})
	for ch in _data.get("cheats", []):
		if mvp_only and not bool(ch.get("mvp", false)):
			continue
		if bool(ch.get("one_time", false)) and bought_one_time.has(ch["id"]):
			continue
		if ch["id"] == "cyber_burn" and cyber_burn_turns > 0:
			continue
		pool.append({"kind": "cheat", "data": ch.duplicate(true)})

	var picked: Array[Dictionary] = []
	if is_first_turn:
		for i in range(pool.size()):
			if pool[i]["kind"] == "cheat" and pool[i]["data"]["id"] == "drone":
				picked.append(pool.pop_at(i))
				break
		var adv_indices: Array[int] = []
		for i in range(pool.size()):
			if pool[i]["kind"] == "advisor":
				adv_indices.append(i)
		if not adv_indices.is_empty():
			var idx: int = adv_indices[_rng.randi_range(0, adv_indices.size() - 1)]
			picked.append(pool.pop_at(idx))

	while picked.size() < 3 and not pool.is_empty():
		var idx := _rng.randi_range(0, pool.size() - 1)
		picked.append(pool.pop_at(idx))

	terminal_cards.clear()
	for p in picked:
		p["bought"] = false
		terminal_cards.append(p)


func _modify_morale(delta: int, source: String, ignore_lock: bool) -> int:
	if delta < 0 and cyber_burn_turns > 0 and not ignore_lock:
		return 0
	var prev := morale
	morale = clampi(morale + delta, 0, get_morale_cap())
	if morale < 40 and not hidden_state["dazexiang"]["found"]:
		hidden_state["dazexiang"]["found"] = true
	if morale < 50 and not mvp_only:
		hidden_state["penglai"]["found"] = true
		hidden_state["antarctica"]["found"] = true
	if morale <= 0 and game_over_code == "":
		_trigger_ending("lose_morale")
	return morale - prev


func _apply_damage(region_id: String, raw_damage: int, instant_kill: bool, source: String) -> Dictionary:
	var r := _find_region(region_id)
	if r.is_empty() or r["conquered"]:
		return {"ok": false, "error": "无效目标"}
	var dmg := int(r["hp"]) if instant_kill else maxi(0, raw_damage)
	r["hp"] = maxi(0, int(r["hp"]) - dmg)
	var conquered_now := false
	if r["hp"] == 0:
		r["conquered"] = true
		conquered_now = true
		if has_advisor("zhangqian"):
			_modify_morale(8, "张骞通商", false)
	strike_performed.emit(region_id, dmg, source, conquered_now)
	if conquered_now and get_conquered_count() >= 6:
		_trigger_ending("win_sage" if morale >= 60 else "win_tyrant")
	return {"ok": true, "damage": dmg, "conquered": conquered_now}


func _trigger_ending(code: String) -> void:
	game_over_code = code
	var ends: Dictionary = _data.get("endings", {})
	game_ended.emit(code, ends.get(code, {}))


func _find_region(region_id: String) -> Dictionary:
	for r in regions:
		if r["id"] == region_id:
			return r
	return {}


func _unconquered_regions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in regions:
		if not r["conquered"]:
			out.append(r)
	return out


func _get_advisor_line(advisor_id: String, bucket: String) -> String:
	var all_adv: Dictionary = _lines.get("advisors", {})
	var entry: Dictionary = all_adv.get(advisor_id, {})
	if entry.is_empty():
		return "谨遵陛下圣命。"
	var val = entry.get(bucket, entry.get("summon", "谨遵圣命。"))
	if val is Array and not val.is_empty():
		return str(val[_rng.randi_range(0, val.size() - 1)])
	return str(val)


func _log(msg: String) -> void:
	logs.push_front("[T%d] %s" % [turn, msg])
	if logs.size() > 40:
		logs.pop_back()


func _emit_state() -> void:
	state_changed.emit(get_snapshot())
