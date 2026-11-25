extends SceneTree
## Godot 4 Headless 一键验收脚本：
## godot --headless --path . -s res://tests/run_tests.gd

func _init() -> void:
	var game_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))
	var lines_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/lines.json"))
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/cases.json"))

	var passed := 0
	var failed := 0

	for tc in cases:
		var ok := _run_case(tc, game_data, lines_data)
		if ok:
			passed += 1
		else:
			failed += 1
			printerr("FAIL [%s]: %s" % [tc["id"], tc["name"]])

	print("Godot 4 GameCore 验收完成: %d/%d 通过 (失败: %d)" % [passed, cases.size(), failed])
	quit(0 if failed == 0 else 1)


func _find_def(arr: Array, id: String) -> Dictionary:
	for x in arr:
		if x["id"] == id:
			return x
	return {}


func _run_case(tc: Dictionary, game_data: Dictionary, lines_data: Dictionary) -> bool:
	var core := GameCore.new()
	core.init_game(game_data, lines_data, bool(tc.get("mvp_only", false)), 42)
	var setup: Dictionary = tc.get("setup", {})
	if setup.has("morale"):
		core.force_morale_for_test(int(setup["morale"]))
	if setup.has("conquered"):
		for rid in setup["conquered"]:
			core.force_region_conquered_for_test(rid)
	if setup.has("sea_unlocked"):
		core.sea_unlocked = bool(setup["sea_unlocked"])
	if setup.has("advisors"):
		for aid in setup["advisors"]:
			var adef := _find_def(game_data["advisors"], aid)
			core.advisors.append(adef.duplicate(true))
		if core.has_advisor("shangyang") and core.morale > 80:
			core.morale = 80
	if setup.has("cards"):
		var injected: Array = []
		for cspec in setup["cards"]:
			if cspec["kind"] == "advisor":
				injected.append({"kind": "advisor", "data": _find_def(game_data["advisors"], cspec["id"])})
			else:
				injected.append({"kind": "cheat", "data": _find_def(game_data["cheats"], cspec["id"])})
		core.set_terminal_cards_for_test(injected)
	if setup.has("free_hook"):
		core.free_hook_available = bool(setup["free_hook"])

	var last_res: Dictionary = {"ok": true}
	for step in tc.get("steps", []):
		match step["op"]:
			"attack":
				last_res = core.conventional_attack(step["target"])
			"buy":
				last_res = core.buy_cheat(int(step["slot"]), step.get("target", ""))
			"summon":
				last_res = core.summon_advisor(int(step["slot"]), int(step.get("replace", -1)))
			"refresh":
				last_res = core.refresh_terminal()
			"fleet":
				last_res = core.build_fleet()
			"hidden":
				last_res = core.trigger_hidden(step["id"])
			"end_turn":
				last_res = core.end_turn()
			"resolve_event":
				last_res = core.resolve_event(step["choice"])

	var exp: Dictionary = tc.get("expect", {})
	var snap := core.get_snapshot()
	if exp.has("last_ok") and bool(last_res.get("ok", false)) != bool(exp["last_ok"]):
		return false
	if exp.has("morale") and int(snap["morale"]) != int(exp["morale"]):
		return false
	if exp.has("morale_cap") and int(snap["morale_cap"]) != int(exp["morale_cap"]):
		return false
	if exp.has("patience") and int(snap["patience"]) != int(exp["patience"]):
		return false
	if exp.has("actions_left") and int(snap["actions_left"]) != int(exp["actions_left"]):
		return false
	if exp.has("attack_left") and int(snap["attack_left"]) != int(exp["attack_left"]):
		return false
	if exp.has("refreshes_left") and int(snap["refreshes_left"]) != int(exp["refreshes_left"]):
		return false
	if exp.has("conventional_power") and int(snap["conventional_power"]) != int(exp["conventional_power"]):
		return false
	if exp.has("conquered_count") and int(snap["conquered_count"]) != int(exp["conquered_count"]):
		return false
	if exp.has("act") and int(snap["act"]) != int(exp["act"]):
		return false
	if exp.has("sea_unlocked") and bool(snap["sea_unlocked"]) != bool(exp["sea_unlocked"]):
		return false
	if exp.has("game_over_code") and str(snap["game_over_code"]) != str(exp["game_over_code"]):
		return false
	if exp.has("region_hp"):
		for rid in exp["region_hp"].keys():
			for r in snap["regions"]:
				if r["id"] == rid and int(r["hp"]) != int(exp["region_hp"][rid]):
					return false
	if exp.has("hidden_visible"):
		for hid in exp["hidden_visible"].keys():
			if bool(snap["hidden_visible"][hid]) != bool(exp["hidden_visible"][hid]):
				return false
	return true
