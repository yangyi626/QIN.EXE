class_name GameCore
extends RefCounted
## 《大秦：2076》纯逻辑核心层（v3.2 · 国师秘技炸场 + 始皇密匣暗黑献祭）
## 严禁引用任何 Node、场景树或 UI 节点；UI 仅订阅下方信号并调用公开命令方法。

signal state_changed(snapshot: Dictionary)
signal strike_performed(region_id: String, damage: int, source: String, conquered: bool)
signal event_triggered(event_data: Dictionary)
signal advisor_spoke(advisor_id: String, advisor_name: String, line: String)
signal hidden_triggered(hidden_id: String, reward_text: String)
signal game_ended(ending_code: String, ending_data: Dictionary)
signal threat_interrupted(region_id: String, reward_text: String)
signal synergy_activated(synergy_name: String, desc: String)
signal decree_completed(title: String, reward_text: String)
signal debate_triggered(debate_data: Dictionary)
signal weakness_hit(region_id: String, bonus_text: String)
signal secret_card_gained(card: Dictionary)
signal pact_made(title: String, desc: String)
signal boss_phase_triggered(region_id: String, title: String, desc: String)
signal paradox_awakened(info: Dictionary)

var _data: Dictionary = {}
var _lines: Dictionary = {}
var _rng := RandomNumberGenerator.new()

var mvp_only: bool = false
var tactical_mode: bool = false
var active_threat: Dictionary = {}
var active_decree: Dictionary = {}
var completed_decrees: Dictionary = {}
var pending_debate: Dictionary = {}
var triggered_debates: Dictionary = {}
var first_mil_used_turn: bool = false
var temp_power_bonus: int = 0
var perm_decree_power_bonus: int = 0
var debate_next_mil_bonus: int = 0
var _announced_synergies: Dictionary = {}
var secret_cards: Array[Dictionary] = []
var interrupt_count: int = 0
var _interrupt_milestone_given: bool = false
var secret_overclock_active: bool = false
var pact_used: bool = false
var pact_morale_cap_penalty: int = 0
var pact_free_hand_turn: bool = false
var paradox_phase: bool = false
var paradox_defeated: bool = false
var paradox_hit_this_turn: bool = false
var corrupted_slot: int = -1
var cipher_0221_used: bool = false
var cipher_2076_used: bool = false
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


func init_game(game_data: Dictionary, lines_data: Dictionary = {}, p_mvp_only: bool = false, rng_seed: int = -1, p_tactical: bool = false) -> void:
	_data = game_data.duplicate(true)
	_lines = lines_data.duplicate(true)
	mvp_only = p_mvp_only
	tactical_mode = p_tactical
	active_threat = {}
	active_decree = {}
	completed_decrees.clear()
	pending_debate = {}
	triggered_debates.clear()
	first_mil_used_turn = false
	temp_power_bonus = 0
	pact_free_hand_turn = false
	secret_overclock_active = false
	perm_decree_power_bonus = 0
	debate_next_mil_bonus = 0
	_announced_synergies.clear()
	secret_cards.clear()
	interrupt_count = 0
	_interrupt_milestone_given = false
	secret_overclock_active = false
	pact_used = false
	pact_morale_cap_penalty = 0
	pact_free_hand_turn = false
	paradox_phase = false
	paradox_defeated = false
	paradox_hit_this_turn = false
	corrupted_slot = -1
	cipher_0221_used = false
	cipher_2076_used = false
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

	var tactical_hp := {"steppe": 25, "west": 50, "south_asia": 85, "west_asia": 130, "europe": 220, "americas": 110}
	regions.clear()
	for r in _data.get("regions", []):
		var copy: Dictionary = r.duplicate(true)
		var base_hp := int(tactical_hp.get(r["id"], int(r["hp"]))) if tactical_mode else int(r["hp"])
		copy["max_hp"] = base_hp
		copy["hp"] = base_hp
		copy["conquered"] = false
		copy["phase2_triggered"] = false
		copy["boss_lock_hp"] = int(ceil(float(base_hp) * 0.5)) if (tactical_mode and r["id"] in ["europe", "americas"]) else 0
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
	if tactical_mode:
		_ensure_act_decree()
		_roll_threat()
	_emit_state()


func has_advisor(advisor_id: String) -> bool:
	for a in advisors:
		if a["id"] == advisor_id:
			return true
	return false


func get_active_synergies() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if not tactical_mode or advisors.size() < 2:
		return list
	if has_advisor("zhugeliang") and has_advisor("caocao"):
		list.append({"id": "wolong_jianxiong", "name": "卧龙奸雄", "desc": "每回合首张军事卡+20伤且免曹操额外-10民心"})
	if has_advisor("hanxin") and has_advisor("huoqubing"):
		list.append({"id": "bingxian_guanjun", "name": "兵仙冠军", "desc": "韩信自动打击升至40，攻克任意板块送1次常规进攻"})
	if has_advisor("libing") and has_advisor("zhangqian"):
		list.append({"id": "silu_shuili", "name": "丝路水利", "desc": "丝路每回合+12民心，买民生卡当回合秦军战力+10"})
	if has_advisor("shangyang") and has_advisor("wanganshi"):
		list.append({"id": "bianfa_shuangbi", "name": "变法双璧", "desc": "解除商鞅80民心上限锁，每回合行动点增至3点"})
	if has_advisor("tanghe"):
		list.append({"id": "wanjia_denghuo", "name": "万家灯火", "desc": "回合结束民心>=60时，对最弱前线造成10点王道感化伤害"})
	if has_advisor("baqing") and has_advisor("zhangqian"):
		list.append({"id": "silu_danshang", "name": "丝路丹商", "desc": "每回合额外+8民心，且终端刷新完全免费"})
	if has_advisor("fuhao") and (has_advisor("huoqubing") or has_advisor("hanxin")):
		list.append({"id": "wushuang_zhanshen", "name": "无双战神", "desc": "常规进攻伤害×1.4，破招打断时额外反击20点伤害"})
	if has_advisor("huangdaopo") and (has_advisor("libing") or has_advisor("tanghe")):
		list.append({"id": "yishi_shouwang", "name": "衣食守望", "desc": "每回合开始民心>=65时，额外+5民心并补充1次免费刷新"})
	if has_advisor("mulan") and (has_advisor("huoqubing") or has_advisor("fuhao")):
		list.append({"id": "juedai_shuangjiao", "name": "绝代双骄", "desc": "每次常规进攻命中额外恢复+4民心"})
	if has_advisor("wuzetian") and (has_advisor("shangyang") or has_advisor("wanganshi")):
		list.append({"id": "qiankun_xinzheng", "name": "乾坤新政", "desc": "所有外挂消耗再降20%，且解除民心上限锁"})
	if has_advisor("liqingzhao") and (has_advisor("zhugeliang") or has_advisor("huangdaopo")):
		list.append({"id": "jinxiu_wenmai", "name": "锦绣文脉", "desc": "终端刷新免费，触发隐藏关额外奖励+10民心"})
	if has_advisor("caiwenji") and (has_advisor("caocao") or has_advisor("zhangqian")):
		list.append({"id": "hujia_guihan", "name": "胡笳归汉", "desc": "终端刷新免费，每次刷新额外回复+6民心"})
	if has_advisor("fanlihua") and (has_advisor("hanxin") or has_advisor("mulan")):
		list.append({"id": "jinguo_bingxian", "name": "巾帼兵仙", "desc": "破城立刻返还1次免费常规进攻，韩信突袭额外+15伤"})
	if has_advisor("banzhao") and (has_advisor("liqingzhao") or has_advisor("caiwenji")):
		list.append({"id": "qianqiu_lantai", "name": "千秋兰台", "desc": "每回合获赠1张【始皇密匣】0费秘策，施放秘策额外+6民心"})
	return list


func has_synergy(syn_id: String) -> bool:
	for s in get_active_synergies():
		if s["id"] == syn_id:
			return true
	return false


func get_region_weakness_info(region_id: String) -> Dictionary:
	match region_id:
		"steppe":
			return {"label": "怕【AK-47/商鞅精锐】：常规进攻暴击 ×1.5", "key": "ak47_or_shangyang"}
		"west":
			return {"label": "怕【无人机蜂群】：额外 +15 突袭伤害", "key": "drone"}
		"south_asia":
			return {"label": "怕【青霉素】：生效当回常规进攻额外 +12 破甲伤", "key": "penicillin"}
		"west_asia":
			return {"label": "怕【无人机蜂群】：沙漠机动克制，额外 +25 伤害", "key": "drone"}
		"europe":
			return {"label": "怕【卫星制导重炮】：重甲破防，额外 +35 伤害", "key": "artillery"}
		"americas":
			return {"label": "怕【跨海铁甲舰】：抢滩奇袭，额外 +25 伤害", "key": "ironclad"}
	return {"label": "无特殊弱点", "key": ""}


func get_morale_cap() -> int:
	var base_cap := 80 if (has_advisor("shangyang") and not has_synergy("bianfa_shuangbi") and not has_synergy("qiankun_xinzheng")) else 100
	return maxi(30, base_cap - pact_morale_cap_penalty)


func get_conquered_count() -> int:
	var count := 0
	for r in regions:
		if r["conquered"] and not bool(r.get("is_paradox_boss", false)):
			count += 1
	return count


func get_act() -> int:
	if paradox_phase:
		return 4
	var c := get_conquered_count()
	if c <= 1:
		return 1
	if c <= 3:
		return 2
	return 3


func get_conventional_power() -> int:
	var base := 20 + cement_road_bonus + ak47_bonus + perm_decree_power_bonus + temp_power_bonus - overheat_power_debuff
	if has_advisor("shangyang"):
		base *= 2
	return maxi(0, base)


func get_effective_cheat_delta(cheat: Dictionary) -> int:
	var delta := int(cheat["morale_delta"])
	if delta >= 0:
		var out := delta * 2 if (cheat["category"] == "livelihood" and has_advisor("libing")) else delta
		if cheat["category"] == "livelihood" and has_advisor("huangdaopo"):
			out += 10
		if cheat["id"] == "education" and has_advisor("liqingzhao"):
			out += 15
		return out
	if pact_free_hand_turn:
		return 0
	if turn == 1 and free_hook_available and cheat["id"] == "drone":
		return 0
	var cost := float(absi(delta))
	var mult := 1.0
	if cheat["category"] == "military" and has_advisor("zhugeliang"):
		mult *= 0.5
	if has_advisor("wanganshi"):
		mult *= 0.8
	if tactical_mode and has_synergy("qiankun_xinzheng"):
		mult *= 0.8
	# v2.1 规定：诸葛亮与王安石同场时 ×0.5 ×0.8 只在最后向上取整一次
	var final_cost := int(ceil(cost * mult))
	if cheat["category"] == "military" and has_advisor("caocao"):
		if not (tactical_mode and not first_mil_used_turn and has_synergy("wolong_jianxiong")):
			final_cost += 10
	if cheat["category"] == "military" and has_advisor("wuzetian"):
		final_cost += 5
	return -final_cost


func get_effective_advisor_cost(adv: Dictionary) -> int:
	if pact_free_hand_turn or (turn == 1 and free_hook_available):
		return 0
	var cost := int(adv["cost"])
	if has_advisor("caiwenji") and str(adv.get("id", "")) != "caiwenji":
		cost = int(ceil(float(cost) * 0.5))
	return cost


func get_fleet_cost() -> int:
	return 15 if (has_advisor("tanghe") or has_advisor("baqing") or has_advisor("banzhao")) else 30


func get_refresh_cost() -> int:
	return 0 if (has_advisor("wanganshi") or has_synergy("silu_danshang") or has_synergy("jinxiu_wenmai") or has_synergy("hujia_guihan")) else 5


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
		"pending_debate": pending_debate.duplicate(true),
		"tactical_mode": tactical_mode,
		"active_threat": active_threat.duplicate(true),
		"active_synergies": get_active_synergies(),
		"active_decree": active_decree.duplicate(true),
		"debate_next_mil_bonus": debate_next_mil_bonus,
		"secret_cards": secret_cards.duplicate(true),
		"secret_overclock_active": secret_overclock_active,
		"paradox_phase": paradox_phase,
		"paradox_defeated": paradox_defeated,
		"corrupted_slot": corrupted_slot,
		"cipher_0221_used": cipher_0221_used,
		"cipher_2076_used": cipher_2076_used,
		"pact_used": pact_used,
		"pact_free_hand_turn": pact_free_hand_turn,
		"game_over_code": game_over_code,
		"logs": logs.duplicate(),
	}


func conventional_attack(region_id: String) -> Dictionary:
	if game_over_code != "" or not pending_event.is_empty() or not pending_debate.is_empty():
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
	if tactical_mode:
		if region_id == "steppe" and (ak47_bonus > 0 or has_advisor("shangyang")):
			dmg = int(floor(float(dmg) * 1.5))
			weakness_hit.emit(region_id, "精锐克制 ×1.5")
		elif region_id == "south_asia" and penicillin_turn:
			dmg += 12
			weakness_hit.emit(region_id, "瘟疫退散 +12")
	attack_left -= 1
	if has_advisor("fuhao"):
		dmg += 15
	if has_advisor("mulan") and (region_id == "steppe" or region_id == "west"):
		dmg += 10
	if tactical_mode and has_synergy("wushuang_zhanshen"):
		dmg = int(floor(float(dmg) * 1.4))
	if tactical_mode and secret_overclock_active:
		dmg *= 2
		secret_overclock_active = false
		weakness_hit.emit(region_id, "乾坤借势 ×2")
	var res := _apply_damage(region_id, dmg, false, "常规秦军")
	if tactical_mode and has_synergy("juedai_shuangjiao"):
		_modify_morale(4, "绝代双骄", false)
	_emit_state()
	return res


func build_fleet() -> Dictionary:
	if game_over_code != "" or not pending_event.is_empty() or not pending_debate.is_empty():
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
	if game_over_code != "" or not pending_event.is_empty() or not pending_debate.is_empty():
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
		if has_advisor("banzhao"):
			_modify_morale(5, "班昭续史明鉴", false)
		if tactical_mode and has_synergy("hujia_guihan"):
			_modify_morale(6, "胡笳归汉", false)
		var purged := (corrupted_slot >= 0)
		corrupted_slot = -1
		_roll_terminal(false)
		_log("终端刷新完成（%s）%s。" % ["免费" if cost == 0 else "-%d 民心" % cost, "，已净化【焚书协议】手牌污染" if purged else ""])
	_emit_state()
	return {"ok": true, "cost": cost}


func summon_advisor(slot_index: int, replace_index: int = -1) -> Dictionary:
	if game_over_code != "" or not pending_event.is_empty() or not pending_debate.is_empty():
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
	if paradox_phase and slot_index == corrupted_slot:
		cost += 10
		corrupted_slot = -1
		_log("⚠ 强行启用【焚书协议】污染槽位，额外损耗 10 民心！")
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
	if tactical_mode:
		for syn in get_active_synergies():
			if not _announced_synergies.has(syn["id"]):
				_announced_synergies[syn["id"]] = true
				_log("✦ 激活名臣羁绊【%s】：%s" % [syn["name"], syn["desc"]])
				synergy_activated.emit(syn["name"], syn["desc"])
				_grant_secret_card("激活羁绊·" + syn["name"])
		_check_decree_progress()
	_emit_state()
	return {"ok": true, "advisor_id": adv["id"], "cost": cost}


func buy_cheat(slot_index: int, target_region_id: String = "") -> Dictionary:
	if game_over_code != "" or not pending_event.is_empty() or not pending_debate.is_empty():
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
	if paradox_phase and slot_index == corrupted_slot:
		eff_delta -= 10
		corrupted_slot = -1
		_log("⚠ 强行启用【焚书协议】污染槽位，额外损耗 10 民心！")
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
	var extra_mil := 0
	if tactical_mode:
		if cheat["category"] == "livelihood" and has_synergy("silu_shuili"):
			temp_power_bonus += 10
			_log("【丝路水利】民生兴邦，本回合常规秦军战力 +10！")
		if has_advisor("huangdaopo"):
			temp_power_bonus += 8
		if cheat["category"] == "military":
			if not first_mil_used_turn and has_synergy("wolong_jianxiong"):
				extra_mil += 20
			first_mil_used_turn = true
			if debate_next_mil_bonus > 0:
				extra_mil += debate_next_mil_bonus
				debate_next_mil_bonus = 0
			if secret_overclock_active:
				cao_mult *= 2
				secret_overclock_active = false
	if cheat["category"] == "military":
		first_mil_used_turn = true
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
			if has_advisor("liqingzhao"):
				_log("【李清照·易安文心】推行义务教育，本回合仍可常规进攻。")
			else:
				education_turn = true
				_log("【义务教育】推行，本回合无法常规进攻。")
		"drone":
			var instant := has_advisor("huoqubing")
			var w_bonus := 0
			if tactical_mode and target_region_id == "west_asia":
				w_bonus = 25
				weakness_hit.emit(target_region_id, "沙漠克制 +25")
			elif tactical_mode and target_region_id == "west":
				w_bonus = 15
				weakness_hit.emit(target_region_id, "戈壁突袭 +15")
			strike_res = _apply_damage(target_region_id, int(cheat["damage"]) * cao_mult + extra_mil + w_bonus, instant, "无人机蜂群")
		"artillery":
			var a_bonus := 0
			if tactical_mode and target_region_id == "europe":
				a_bonus = 35
				weakness_hit.emit(target_region_id, "重甲破防 +35")
			strike_res = _apply_damage(target_region_id, int(cheat["damage"]) * cao_mult + extra_mil + a_bonus, false, "卫星制导重炮")
		"ak47":
			ak47_bonus += 30 * cao_mult
			_log("【AK-47 兵马俑】列装，常规秦军永久 +%d。" % (30 * cao_mult))
		"ironclad":
			sea_unlocked = true
			var i_bonus := 0
			if tactical_mode and target_region_id == "americas":
				i_bonus = 25
				weakness_hit.emit(target_region_id, "抢滩奇袭 +25")
			strike_res = _apply_damage(target_region_id, int(cheat["damage"]) * cao_mult + extra_mil + i_bonus, false, "跨海铁甲舰")
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
	if game_over_code != "" or not pending_event.is_empty() or not pending_debate.is_empty():
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

	if tactical_mode and has_synergy("jinxiu_wenmai"):
		_modify_morale(10, "锦绣文脉", false)
	_emit_state()
	return {"ok": true, "hidden_id": hidden_id}


func end_turn() -> Dictionary:
	if game_over_code != "" or not pending_event.is_empty() or not pending_debate.is_empty():
		return {"ok": false, "error": "当前无法结束回合"}

	if has_advisor("caiwenji") and not first_mil_used_turn:
		_modify_morale(8, "蔡文姬胡笳安民", false)

	if tactical_mode:
		# 万家灯火羁绊：民心 >= 60 时自动对最弱前线造成 10 点王道感化伤
		if has_synergy("wanjia_denghuo") and morale >= 60:
			var front := _unconquered_regions()
			if not front.is_empty():
				front.sort_custom(func(a, b): return int(a["hp"]) < int(b["hp"]))
				_apply_damage(front[0]["id"], 10, false, "万家灯火感化")
				if game_over_code != "":
					_emit_state()
					return {"ok": true}
		# 结算未被破招打断的敌军意图
		_resolve_threat_on_end_turn()
		if game_over_code != "":
			_emit_state()
			return {"ok": true}
		# 2076 焚书协议终极核心回合末反噬
		if paradox_phase and not paradox_defeated:
			var p_loss := 6 if paradox_hit_this_turn else 12
			_modify_morale(-p_loss, "2076终端余波反噬" if paradox_hit_this_turn else "2076焚书协议反噬", false)
			_log("⚠ 【2076 焚书协议】核心扫射沙盘：民心 -%d%s！" % [p_loss, "（本回合已压制减半）" if paradox_hit_this_turn else "（未攻击核心承受全额反噬）"])
		if game_over_code != "":
			_emit_state()
			return {"ok": true}

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
		if has_advisor("wuzetian"):
			_modify_morale(5, ev["title"] + "·女帝借势", false)
		else:
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
	paradox_hit_this_turn = false
	turn += 1
	patience -= 1
	if patience <= 0:
		_trigger_ending("lose_time")
		return

	var base_actions := 2 + (1 if (tactical_mode and has_synergy("bianfa_shuangbi")) else 0) + (1 if has_advisor("wuzetian") else 0)
	actions_left = maxi(0, base_actions - next_turn_action_penalty)
	next_turn_action_penalty = 0
	attack_left = 2 if has_advisor("mulan") else 1
	refreshes_left = 0 if overheat_no_refresh else 3
	penicillin_turn = false
	education_turn = false
	free_hook_available = false
	first_mil_used_turn = false
	debate_next_mil_bonus = 0
	temp_power_bonus = 0
	pact_free_hand_turn = false
	secret_overclock_active = false

	# v2.1 固定回合开始结算顺序：1.丝路 -> 2.贷款 -> 3.韩信 -> 4.刷新终端
	if has_advisor("baqing"):
		_modify_morale(6, "巴清丹穴矿脉", false)
	if has_advisor("liqingzhao"):
		_modify_morale(4, "李清照易安文心", false)
	if tactical_mode and has_synergy("silu_danshang"):
		_modify_morale(8, "丝路丹商共鸣", false)
	if tactical_mode and has_synergy("yishi_shouwang") and morale >= 65:
		_modify_morale(5, "衣食守望", false)
		refreshes_left = mini(3, refreshes_left + 1)
	if tactical_mode and has_synergy("qianqiu_lantai"):
		_grant_secret_card("千秋兰台")
	var west := _find_region("west")
	if not west.is_empty() and west["conquered"]:
		var silk_gain := 12 if (tactical_mode and has_synergy("silu_shuili")) else 5
		_modify_morale(silk_gain, "丝绸之路红利", false)

	if not loan_queue.is_empty():
		var due: int = loan_queue.pop_front()
		_modify_morale(-due, "跨时空贷款", false)
		if game_over_code != "":
			return

	if has_advisor("hanxin"):
		var targets := _unconquered_regions()
		if not targets.is_empty():
			var t: Dictionary = targets[_rng.randi_range(0, targets.size() - 1)]
			var hx_dmg := 25 + (15 if (tactical_mode and has_synergy("bingxian_guanjun")) else 0) + (15 if (tactical_mode and has_synergy("jinguo_bingxian")) else 0)
			_apply_damage(t["id"], hx_dmg, false, "韩信自动打击")
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

	if tactical_mode and game_over_code == "":
		_ensure_act_decree()
		if paradox_phase and not paradox_defeated:
			_corrupt_random_slot()
			active_threat = {
				"region_id": "paradox_core",
				"type": "raid",
				"title": "焚书协议清洗",
				"desc": "回合结束未打断：民心 -10（汤和减半）",
				"interrupted": false,
			}
		else:
			_roll_threat()
		_maybe_trigger_debate()


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
	var old_hp := int(r["hp"])
	var dmg := old_hp if instant_kill else maxi(0, raw_damage)
	if region_id == "paradox_core" and dmg > 0:
		paradox_hit_this_turn = true
	var interrupts: bool = tactical_mode and dmg > 0 and active_threat.get("region_id", "") == region_id and not bool(active_threat.get("interrupted", false))
	if interrupts and dmg < old_hp and has_synergy("wushuang_zhanshen"):
		dmg += 20
		_log("⚔【无双战神】破招追击！对【%s】追加 20 点伤害。" % r["name"])
	if interrupts and dmg < old_hp and has_advisor("fanlihua"):
		dmg += 25
		_log("⚔【樊梨花·奇门破阵】对【%s】追加 25 点穿甲伤害。" % r["name"])
	var lock_hp := int(r.get("boss_lock_hp", 0))
	var phase2_just_triggered := false
	if tactical_mode and lock_hp > 0 and not bool(r.get("phase2_triggered", false)) and (old_hp - dmg <= lock_hp):
		r["hp"] = lock_hp
		r["phase2_triggered"] = true
		dmg = maxi(0, old_hp - lock_hp)
		phase2_just_triggered = true
	else:
		r["hp"] = maxi(0, old_hp - dmg)
	var conquered_now := false
	if r["hp"] == 0:
		r["conquered"] = true
		conquered_now = true
		if has_advisor("zhangqian"):
			_modify_morale(8, "张骞通商", false)
		if has_advisor("fuhao"):
			_modify_morale(6, "妇好凯旋", false)
		if has_advisor("fanlihua"):
			_modify_morale(10, "樊梨花凯旋", false)
	if interrupts:
		active_threat["interrupted"] = true
		_modify_morale(5, "破招打断敌军意图", false)
		_log("⚡ 破招打断【%s】！民心 +5。" % active_threat["title"])
		interrupt_count += 1
		threat_interrupted.emit(region_id, "破招成功！民心 +5")
		if interrupt_count >= 2 and not _interrupt_milestone_given:
			_interrupt_milestone_given = true
			_grant_secret_card("连破敌招")
	if tactical_mode and conquered_now and (has_synergy("bingxian_guanjun") or has_synergy("jinguo_bingxian")):
		attack_left += 1
		_log("【%s】乘胜追击！额外获得 1 次免费常规进攻！" % ("巾帼兵仙" if has_synergy("jinguo_bingxian") else "兵仙冠军"))
	strike_performed.emit(region_id, dmg, source, conquered_now)
	if phase2_just_triggered:
		_trigger_boss_phase2(r)
	if conquered_now and region_id == "paradox_core":
		paradox_defeated = true
		corrupted_slot = -1
		_log("✦ 【2076 焚书终端核心】彻底粉碎！你打破了时空闭环，成就真正的万世国师！")
		_trigger_ending("win_sage" if morale >= 60 else "win_tyrant")
	elif conquered_now and get_conquered_count() >= 6:
		if tactical_mode and not paradox_phase and not paradox_defeated:
			_awaken_paradox_boss()
		else:
			_trigger_ending("win_sage" if morale >= 60 else "win_tyrant")
	elif tactical_mode:
		_check_decree_progress()
	return {"ok": true, "damage": dmg, "conquered": conquered_now}


func _trigger_boss_phase2(r: Dictionary) -> void:
	var rid: String = r["id"]
	var title := "二阶段铁壁"
	var desc := "锁血抵消溢出伤害并立刻反扑！"
	if rid == "europe":
		title = "罗马龟甲铁壁"
		desc = "锁血 110 抵消溢出伤害！民心 -8，冻结 1 次终端刷新，并立刻发起反扑！"
		_modify_morale(-8, "罗马龟甲铁壁反扑", false)
		refreshes_left = maxi(0, refreshes_left - 1)
		active_threat = {
			"region_id": "europe",
			"type": "raid",
			"title": "罗马龟甲反扑",
			"desc": "回合结束未打断：民心 -10（汤和减半）",
			"interrupted": false,
		}
	elif rid == "americas":
		title = "跨海飓风风暴"
		desc = "锁血 55 抵消溢出伤害！民心 -10，大洋风暴直指楼船航线，需立刻破招！"
		_modify_morale(-10, "跨海飓风反噬", false)
		active_threat = {
			"region_id": "americas",
			"type": "sabotage",
			"title": "大洋飓风反噬",
			"desc": "回合结束未打断：下回合行动 -1",
			"interrupted": false,
		}
	elif rid == "paradox_core":
		title = "时空回溯·协议过载"
		desc = "锁血 130 抵消溢出伤害！民心 -10，并立刻重新污染 1 张终端手牌！"
		_modify_morale(-10, "焚书协议过载", false)
		_corrupt_random_slot()
	_log("⚠ 【%s】触发二阶段【%s】：%s" % [r["name"], title, desc])
	boss_phase_triggered.emit(rid, title, desc)


func _corrupt_random_slot() -> void:
	var open_slots: Array[int] = []
	for i in range(terminal_cards.size()):
		if not bool(terminal_cards[i].get("bought", false)):
			open_slots.append(i)
	if open_slots.is_empty():
		corrupted_slot = -1
	else:
		corrupted_slot = open_slots[_rng.randi_range(0, open_slots.size() - 1)]


func _awaken_paradox_boss() -> void:
	paradox_phase = true
	paradox_hit_this_turn = false
	if patience < 4:
		patience = 4
	var core_boss := {
		"id": "paradox_core",
		"name": "2076·焚书终端核心",
		"coverage": "2076 悖论终端",
		"landmark_name": "焚书协议核心矩阵",
		"landmark": "res://assets/landmarks/paradox_core.jpg",
		"reward": "击碎时空闭环，成就真正的万世国师",
		"efficiency": 1.0,
		"hp": 260,
		"max_hp": 260,
		"prereq": "",
		"requires_sea": false,
		"conquered": false,
		"boss_lock_hp": 130,
		"phase2_triggered": false,
		"is_paradox_boss": true,
	}
	regions.append(core_boss)
	_corrupt_random_slot()
	active_threat = {
		"region_id": "paradox_core",
		"type": "raid",
		"title": "焚书协议清洗",
		"desc": "回合结束未打断：民心 -10（汤和减半）",
		"interrupted": false,
	}
	_log("⚠ 警告：历史修正率 100%！2076 未来终端启动【焚书协议】，终极核心(260血)降临沙盘中央！")
	paradox_awakened.emit({"hp": 260, "patience": patience, "corrupted_slot": corrupted_slot})


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


# --- 深度博弈与牌桌 NPC 实时介入（仅 tactical_mode = true 时生效） ---
func _roll_threat() -> void:
	active_threat = {}
	var candidates: Array[Dictionary] = []
	for r in regions:
		if not r["conquered"] and can_attack_region(r["id"]):
			candidates.append(r)
	if candidates.is_empty():
		candidates = _unconquered_regions()
	if candidates.is_empty():
		return
	var target: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var types := [
		{"type": "raid", "title": "边疆劫掠", "desc": "回合结束未打断：民心 -10（汤和减半）"},
		{"type": "fortify", "title": "紧急筑城", "desc": "回合结束未打断：该洲守军恢复 +15"},
		{"type": "sabotage", "title": "截断粮道", "desc": "回合结束未打断：下回合行动 -1"},
	]
	var pick: Dictionary = types[_rng.randi_range(0, types.size() - 1)]
	active_threat = {
		"region_id": target["id"],
		"region_name": target["name"],
		"type": pick["type"],
		"title": pick["title"],
		"desc": pick["desc"],
		"interrupted": false,
	}


func _resolve_threat_on_end_turn() -> void:
	if active_threat.is_empty() or bool(active_threat.get("interrupted", false)):
		return
	var rid: String = active_threat["region_id"]
	var r := _find_region(rid)
	if r.is_empty() or r["conquered"]:
		return
	match active_threat["type"]:
		"raid":
			var loss := 5 if has_advisor("tanghe") else 10
			_log("⚠ 敌军【%s·边疆劫掠】未打断，民心 -%d！" % [r["name"], loss])
			_modify_morale(-loss, "敌军劫掠", false)
		"fortify":
			r["hp"] = mini(int(r["max_hp"]), int(r["hp"]) + 15)
			_log("⚠ 敌军【%s·紧急筑城】未打断，守军恢复 +15！" % r["name"])
		"sabotage":
			next_turn_action_penalty += 1
			_log("⚠ 敌军【%s·截断粮道】未打断，下回合行动 -1！" % r["name"])


func _ensure_act_decree() -> void:
	var act := get_act()
	if not active_decree.is_empty() and int(active_decree.get("act", 0)) == act:
		return
	if completed_decrees.has(act):
		active_decree = {}
		return
	match act:
		1:
			active_decree = {"act": 1, "id": "decree_west", "title": "初征御旨", "goal": "第 4 回合前攻克【西域与中亚】", "reward": "民心 +15 · 耐心 +1", "done": false}
		2:
			active_decree = {"act": 2, "id": "decree_interrupt", "title": "守民御旨", "goal": "破招打断敌军意图且保持民心 ≥ 55", "reward": "常规秦军永久 +15 战力", "done": false}
		3:
			active_decree = {"act": 3, "id": "decree_final", "title": "决战御旨", "goal": "满编 2 名臣且攻克欧罗巴或美洲", "reward": "民心 +20 · 行动 +1", "done": false}


func _check_decree_progress() -> void:
	if active_decree.is_empty() or bool(active_decree.get("done", false)):
		return
	var ok := false
	match active_decree["id"]:
		"decree_west":
			var w := _find_region("west")
			ok = (not w.is_empty() and w["conquered"] and turn <= 4)
			if ok:
				_modify_morale(15, "初征御旨赏赐", false)
				patience += 1
		"decree_interrupt":
			ok = (not active_threat.is_empty() and bool(active_threat.get("interrupted", false)) and morale >= 55)
			if ok:
				perm_decree_power_bonus += 15
		"decree_final":
			var eu := _find_region("europe")
			var am := _find_region("americas")
			ok = (advisors.size() >= 2 and ((not eu.is_empty() and eu["conquered"]) or (not am.is_empty() and am["conquered"])))
			if ok:
				_modify_morale(20, "决战御旨赏赐", false)
				actions_left += 1
	if ok:
		active_decree["done"] = true
		completed_decrees[active_decree["act"]] = true
		_log("👑 完成始皇【%s】！赏赐：%s。" % [active_decree["title"], active_decree["reward"]])
		decree_completed.emit(active_decree["title"], active_decree["reward"])
		_grant_secret_card("完成御旨·" + active_decree["title"])


func _maybe_trigger_debate() -> void:
	if advisors.size() < 2 or not pending_event.is_empty() or not pending_debate.is_empty():
		return
	if turn not in [2, 5, 8] or triggered_debates.has(turn):
		return
	triggered_debates[turn] = true
	var a0: Dictionary = advisors[0]
	var a1: Dictionary = advisors[1]
	var opt0 := _advisor_debate_offer(a0)
	var opt1 := _advisor_debate_offer(a1)
	pending_debate = {
		"turn": turn,
		"advisor_a": a0.duplicate(true),
		"advisor_b": a1.duplicate(true),
		"option_a": opt0,
		"option_b": opt1,
	}
	debate_triggered.emit(pending_debate)


func _advisor_debate_offer(adv: Dictionary) -> Dictionary:
	var aid: String = adv["id"]
	if aid in ["zhugeliang", "libing", "zhangqian", "tanghe", "baqing", "huangdaopo", "liqingzhao", "caiwenji", "banzhao"]:
		return {
			"quote": "陛下，宜先安万民之心，方能长治久安！",
			"label": "采纳【%s】：民心 +14，并免费获 1 次刷新" % adv["name"],
			"effect": "benevolent",
		}
	return {
		"quote": "机不可失！当以雷霆科技一举碾碎强敌！",
		"label": "采纳【%s】：本回合下张军事外挂 +30 伤（民心 -6）" % adv["name"],
		"effect": "aggressive",
	}


func resolve_debate(choice: String) -> Dictionary:
	if pending_debate.is_empty():
		return {"ok": false, "error": "当前没有待裁决的朝堂争辩"}
	var d := pending_debate
	pending_debate = {}
	var picked: Dictionary = d["option_a"] if choice == "A" else d["option_b"]
	var adv: Dictionary = d["advisor_a"] if choice == "A" else d["advisor_b"]
	if picked["effect"] == "benevolent":
		_modify_morale(14, "朝堂争辩·" + adv["name"], false)
		refreshes_left = mini(3, refreshes_left + 1)
		_log("你采纳了【%s】的仁政之议：民心 +14，刷新 +1。" % adv["name"])
	else:
		debate_next_mil_bonus += 30
		_modify_morale(-6, "朝堂争辩·" + adv["name"], false)
		_log("你采纳了【%s】的铁血之议：下张军事外挂 +30 伤，民心 -6。" % adv["name"])
	_emit_state()
	return {"ok": true}


# --- 王者万象棋式「国师秘技炸场」与邪恶冥刻式「始皇密匣暗黑献祭」 ---
func _grant_secret_card(reason: String) -> void:
	if not tactical_mode or secret_cards.size() >= 2:
		return
	var pool := [
		{"id": "secret_barrage", "name": "万剑归秦", "desc": "0费不占行动：全图未占领板块齐劈30点天雷，击穿任意洲触发15点连锁余震！"},
		{"id": "secret_revival", "name": "天命所归", "desc": "0费不占行动：立刻 +25 民心、本回合行动 +1、免费常规进攻 +1！"},
		{"id": "secret_overclock", "name": "乾坤借势", "desc": "0费不占行动：下一次进攻/军事外挂伤害翻倍(×2)，并免费刷新手牌！"},
	]
	var pick: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)].duplicate(true)
	secret_cards.append(pick)
	_log("★ 达成【%s】，天降 0 费金色国师秘技【%s】！" % [reason, pick["name"]])
	secret_card_gained.emit(pick)


func cast_secret_card(index: int) -> Dictionary:
	if not tactical_mode:
		return {"ok": false, "error": "仅深度博弈模式可用"}
	if game_over_code != "" or not pending_event.is_empty() or not pending_debate.is_empty():
		return {"ok": false, "error": "当前状态不可释放秘技"}
	if index < 0 or index >= secret_cards.size():
		return {"ok": false, "error": "秘技槽位无效"}
	var card: Dictionary = secret_cards[index]
	secret_cards.remove_at(index)
	match card["id"]:
		"secret_barrage":
			_log("⚡ 释放国师秘技【万剑归秦】：天雷齐降六洲！")
			var any_conquered := false
			for r in _unconquered_regions():
				var sr := _apply_damage(r["id"], 30, false, "万剑归秦天雷")
				if bool(sr.get("conquered", false)):
					any_conquered = true
				if game_over_code != "":
					_emit_state()
					return {"ok": true, "secret_id": card["id"]}
			if any_conquered:
				_log("⚡ 【万剑归秦】触发击穿连锁余震！全图再劈 15 伤害！")
				for r2 in _unconquered_regions():
					_apply_damage(r2["id"], 15, false, "万剑连锁余震")
					if game_over_code != "":
						break
		"secret_revival":
			_modify_morale(25, "国师秘技·天命所归", false)
			actions_left += 1
			attack_left += 1
			_log("★ 释放【天命所归】：民心 +25，行动 +1，常规进攻 +1！")
		"secret_overclock":
			secret_overclock_active = true
			_roll_terminal(false)
			_log("★ 释放【乾坤借势】：下次攻击伤害 ×2，终端手牌免费重抽！")
		"secret_cipher_key":
			corrupted_slot = -1
			if paradox_phase and not paradox_defeated:
				var pc := _find_region("paradox_core")
				if not pc.is_empty():
					pc["phase2_triggered"] = true
					_log("🔑 释放隐藏神卡【传国密钥·破壁】：直接粉碎 2076 终端锁血护盾并净化手牌污染！")
					_apply_damage("paradox_core", 90, false, "传国密钥·破壁")
			else:
				_log("🔑 释放隐藏神卡【传国密钥·破壁】：全图 45 点无视护甲穿刺打击！")
				for r_ck in _unconquered_regions():
					_apply_damage(r_ck["id"], 45, false, "传国密钥·破壁")
					if game_over_code != "":
						break
		"legacy_strike":
			_log("📜 启用先师遗诏【%s】：全图 40 伤并回复 10 民心！" % card["name"])
			_modify_morale(10, "先师遗诏·破阵遗锋", false)
			for r_ls in _unconquered_regions():
				_apply_damage(r_ls["id"], 40, false, card["name"])
				if game_over_code != "":
					break
		"legacy_morale":
			_modify_morale(30, "先师遗诏·万民遗泽", false)
			actions_left += 1
			refreshes_left = mini(3, refreshes_left + 1)
			_log("📜 启用先师遗诏【%s】：民心 +30，行动 +1，刷新 +1！" % card["name"])
		"legacy_overclock":
			secret_overclock_active = true
			attack_left += 1
			_roll_terminal(false)
			_log("📜 启用先师遗诏【%s】：下次攻击伤害 ×2，常规进攻 +1，手牌免费重抽！" % card["name"])
	if has_synergy("qianqiu_lantai"):
		_modify_morale(6, "千秋兰台", false)
	_emit_state()
	return {"ok": true, "secret_id": card["id"]}


func make_emperor_pact(choice: String) -> Dictionary:
	if not tactical_mode:
		return {"ok": false, "error": "仅深度博弈模式可用"}
	if pact_used:
		return {"ok": false, "error": "本局始皇密匣已开启过"}
	if game_over_code != "" or not pending_event.is_empty() or not pending_debate.is_empty():
		return {"ok": false, "error": "当前状态不可开启密匣"}
	match choice:
		"sacrifice":
			pact_used = true
			var cost_txt := ""
			if not advisors.is_empty():
				var gone: Dictionary = advisors.pop_front()
				cost_txt = "献祭名臣【%s】" % gone["name"]
			else:
				_modify_morale(-20, "始皇密匣·焚鼎献祭", false)
				cost_txt = "献祭 20 民心"
				if game_over_code != "":
					_emit_state()
					return {"ok": true}
			pact_free_hand_turn = true
			actions_left += 1
			_log("🔥 开启始皇密匣【焚鼎献祭】：%s，本回合全部手牌 0 民心消耗且行动 +1！" % cost_txt)
			pact_made.emit("焚鼎献祭", "%s → 本回合全手牌免民心 · 行动 +1" % cost_txt)
		"steal_time":
			pact_used = true
			pact_morale_cap_penalty += 25
			morale = mini(morale, get_morale_cap())
			patience += 4
			_log("🔥 开启始皇密匣【盗取天时】：本局民心上限永久 -25，始皇耐心 +4 回合！")
			pact_made.emit("盗取天时", "民心上限永久 -25 → 始皇耐心 +4 回合 · 获赠国师秘技")
			_grant_secret_card("始皇密匣·盗取天时")
		_:
			return {"ok": false, "error": "未知密匣契约"}
	_emit_state()
	return {"ok": true}


func redeem_crt_cipher(code: String) -> Dictionary:
	if game_over_code != "":
		return {"ok": false, "error": "本局已结束，无法执行终端指令"}
	var c := code.strip_edges()
	if c == "0221":
		if cipher_0221_used:
			return {"ok": false, "error": "本局已激活过 0221 始皇元年权限"}
		cipher_0221_used = true
		var key_card := {
			"id": "secret_cipher_key",
			"name": "传国密钥·破壁",
			"desc": "0费全图45伤；终幕直接击穿焚书核心锁血护盾并造成90重创+净化污染",
		}
		secret_cards.append(key_card)
		_log("🔑 骇入 2076 终端成功（秘钥 0221）！获赠隐藏 0 费神卡【传国密钥·破壁】！")
		secret_card_gained.emit(key_card)
		_emit_state()
		return {"ok": true, "code": "0221", "title": "骇入成功 · 0221 始皇元年权限", "msg": "已解锁隐藏 0 费神卡【传国密钥·破壁】！终幕可直接粉碎核心锁血护盾！"}
	elif c == "2076":
		if cipher_2076_used:
			return {"ok": false, "error": "本局已领取过 2076 未来纪元补给"}
		cipher_2076_used = true
		_modify_morale(15, "2076底层补给", false)
		refreshes_left = mini(3, refreshes_left + 1)
		_grant_secret_card("2076纪元密令")
		_log("⚡ 彩蛋秘钥 2076 生效！民心 +15，刷新 +1，获赠 1 张国师秘技！")
		_emit_state()
		return {"ok": true, "code": "2076", "title": "彩蛋权限 · 2076 未来纪元", "msg": "民心 +15 · 刷新 +1 · 获赠 1 张 0 费国师秘技！"}
	return {"ok": false, "error": "ACCESS DENIED // 秘钥错误（线索藏于左侧青铜鼎铭文与藏经阁咸阳宫碑文）"}


func inject_legacy_card(card: Dictionary) -> void:
	if card.is_empty() or not card.has("id"):
		return
	secret_cards.append(card.duplicate(true))
	_log("📜 继承上局先师遗志：【%s】已置入秘技栏（0费可用一次）！" % str(card.get("name", "先师遗诏")))
	_emit_state()
