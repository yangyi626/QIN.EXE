extends Node3D
## 《大秦：2076》3D 玄黑沙盘主场景与 UI 表现层（v2.1）
## 严格遵循逻辑与表现分离：仅调用 GameCore 公开方法并订阅信号，不反向篡改核心状态。

@onready var camera: Camera3D = $Camera3D

var core := GameCore.new()
var _game_data: Dictionary = {}
var _lines_data: Dictionary = {}
var _mvp_only: bool = false

# 3D 场景引用
var _region_meshes: Dictionary = {} # region_id -> MeshInstance3D (全息据点信标盘)
var _pins: Dictionary = {}
var _bars: Dictionary = {}
var _latest: Dictionary
var _selected := ""
var _map_material := ShaderMaterial.new()
var _map: Control
var _detail: Label
var _attack: Button
var _cancel: Button
var _report: Label
var _camera_tween: Tween
const GOLD := Color("#edbe74")
const CYAN := Color("#7adfd7")
const MUTED := Color("#a2b5b4")
const PIN_OFFSETS := {
	"americas": Vector2(-100, 16), "europe": Vector2(-129, -58),
	"west_asia": Vector2(-133, 30), "steppe": Vector2(15, -75),
	"west": Vector2(-54, -59), "south_asia": Vector2(19, 15)
}
const PIN_SIZE := Vector2(110, 49)

var _region_pos: Dictionary = {}    # region_id -> Vector3
var _hidden_nodes: Dictionary = {}  # hidden_id -> MeshInstance3D
var _holo_sprites: Array[Sprite3D] = []
var _cauldron_light: OmniLight3D

# 交互状态
var _pending_cheat_slot: int = -1
var _camera_mode: String = "sandtable" # "sandtable" | "terminal"

# UI 节点引用
var _lbl_morale: Label
var _lbl_conquest: Label
var _lbl_patience: Label
var _lbl_act: Label
var _lbl_actions: Label
var _lbl_banter: Label
var _btn_refresh: Button
var _btn_fleet: Button
var _btn_pool: Button
var _cards_box: VBoxContainer
var _modal_shade: ColorRect
var _hidden_box: HBoxContainer
var _event_panel: PanelContainer
var _event_title: Label
var _event_desc: Label
var _event_btn_a: Button
var _event_btn_b: Button
var _ending_panel: PanelContainer
var _ending_title: Label
var _ending_desc: Label


func _ready() -> void:
	_game_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))
	_lines_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/lines.json"))

	_build_3d_sandtable()
	_build_ui_overlay()

	core.state_changed.connect(_on_state_changed)
	core.strike_performed.connect(_on_strike_performed)
	core.event_triggered.connect(_on_event_triggered)
	core.advisor_spoke.connect(_on_advisor_spoke)
	core.hidden_triggered.connect(_on_hidden_triggered)
	core.game_ended.connect(_on_game_ended)

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	get_viewport().size_changed.connect(_frame_map)
	_frame_map()
	_restart()


func _build_3d_sandtable() -> void:
	# 1. 玄黑暗青铜桌面底座
	var table := MeshInstance3D.new()
	var table_mesh := BoxMesh.new()
	table_mesh.size = Vector3(14.8, 0.6, 8.8)
	table.mesh = table_mesh
	var table_mat := StandardMaterial3D.new()
	table_mat.albedo_color = Color("#181512")
	table_mat.metallic = 0.58
	table_mat.roughness = 0.48
	table.material_override = table_mat
	table.position = Vector3(0, -0.35, 0)
	add_child(table)

	# 1b. 玄黑青铜世界地图顶视贴图桌面（16:9 精准贴合）
	var map_plane := MeshInstance3D.new()
	var pmesh := PlaneMesh.new()
	pmesh.size = Vector2(14.0, 7.875)
	map_plane.mesh = pmesh
	_map_material.shader = preload("res://shaders/territory_map.gdshader")
	_map_material.set_shader_parameter("atlas", preload("res://assets/textures/sandtable_map.jpg"))
	var sites := PackedVector2Array()
	for region in _game_data.regions:
		var point: Array = region.pos3d
		sites.append(Vector2(0.5 + point[0] / pmesh.size.x, 0.5 + point[2] / pmesh.size.y))
	sites.append(Vector2(0.5 + 3.64 / pmesh.size.x, 0.5 - 0.71 / pmesh.size.y))
	_map_material.set_shader_parameter("sites", sites)
	map_plane.material_override = _map_material
	map_plane.position = Vector3(0, -0.04, 0)
	add_child(map_plane)

	# 2. 大秦咸阳本土鎏金信标（对齐世界地图中发光的中国版图）
	var qin := _make_beacon(Vector3(3.64, 0.04, -0.71), 0.18, 0.06, Color("#0B0D10"), Color("#FFB347"))
	add_child(qin)
	var qin_lbl := _make_label3d(Vector3(4.23, 0.28, -0.71), "大秦·咸阳", Color("#FFB347"))
	add_child(qin_lbl)

	# 3. 全球 6 大板块全息信标盘 + 悬浮战力标牌（不遮挡底图版图浮雕）
	for r in _game_data.get("regions", []):
		var p: Array = r["pos3d"]
		var pos := Vector3(p[0], 0.04, p[2])
		var beacon := _make_beacon(pos, 0.16, 0.05, Color("#2C2620"), Color("#00F0FF"))
		add_child(beacon)
		_region_meshes[r["id"]] = beacon
		_region_pos[r["id"]] = pos



	_cauldron_light = OmniLight3D.new()
	_cauldron_light.position = Vector3(-6.4, 1.4, 3.2)
	_cauldron_light.light_color = Color("#FFB347")
	_cauldron_light.light_energy = 2.4
	_cauldron_light.omni_range = 13.0
	add_child(_cauldron_light)


	# 6. 沙盘对面 2 个 AI 名臣全息投影位（共用 hologram.gdshader）
	var shader: Shader = load("res://shaders/hologram.gdshader")
	for x_pos in [-3.4, 3.4]:
		var sp := Sprite3D.new()
		sp.position = Vector3(x_pos, 1.65, -4.8)
		sp.pixel_size = 0.0065
		sp.visible = false
		var smat := ShaderMaterial.new()
		smat.shader = shader
		sp.material_override = smat
		add_child(sp)
		_holo_sprites.append(sp)

	# 7. 三大隐藏关异常微光点（贴合东海/大秦腹地/南极）
	var hidden_coords := {
		"penglai": [Vector3(5.32, 0.28, -0.63), Color("#00F0FF")],
		"dazexiang": [Vector3(3.92, 0.28, -0.39), Color("#FF2A2A")],
		"antarctica": [Vector3(0.0, 0.28, 3.15), Color("#00F0FF")],
	}
	for hid in hidden_coords.keys():
		var hnode := _make_block(hidden_coords[hid][0], Vector3(0.28, 0.28, 0.28), hidden_coords[hid][1], hidden_coords[hid][1])
		hnode.visible = false
		add_child(hnode)
		_hidden_nodes[hid] = hnode


func _make_block(pos: Vector3, sz: Vector3, col: Color, emi: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = sz
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = emi
	mat.emission_energy_multiplier = 0.35
	m.material_override = mat
	m.position = pos
	return m


func _make_beacon(pos: Vector3, radius: float, height: float, col: Color, emi: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 1.12
	cyl.height = height
	cyl.radial_segments = 24
	m.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = 0.6
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = emi
	mat.emission_energy_multiplier = 0.55
	m.material_override = mat
	m.position = pos
	return m


func _make_label3d(pos: Vector3, txt: String, col: Color) -> Label3D:
	var lbl := Label3D.new()
	lbl.position = pos
	lbl.text = txt
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 36
	lbl.outline_size = 8
	lbl.modulate = col
	lbl.pixel_size = 0.008
	return lbl


func _spawn_strike_fx(region_id: String, conquered: bool) -> void:
	if not _region_pos.has(region_id):
		return
	var target: Vector3 = _region_pos[region_id]
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045 if not conquered else 0.08
	cyl.bottom_radius = 0.16 if not conquered else 0.25
	cyl.height = 2.8
	beam.mesh = cyl
	var mat := StandardMaterial3D.new()
	var fx_col := Color("#FFB347") if conquered else Color("#00F0FF")
	mat.albedo_color = fx_col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = fx_col
	mat.emission_energy_multiplier = 3.2
	beam.material_override = mat
	beam.position = target + Vector3(0, 1.4, 0)
	add_child(beam)

	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(beam, "scale", Vector3(1.8, 1.0, 1.8), 0.42)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.42)
	tw.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, 0.42)
	tw.finished.connect(beam.queue_free)


func _style(bg: Color, edge: Color, pad: int = 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(1)
	box.border_color = edge
	box.set_corner_radius_all(4)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		box.set_content_margin(side, pad)
	return box


func _label(parent: Control, title: String, pixels: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", pixels)
	label.modulate = tint
	parent.add_child(label)
	return label


func _button(parent: Control, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _style(Color("#17252b"), Color("#395052"), 6))
	button.add_theme_stylebox_override("hover", _style(Color("#284044"), CYAN, 6))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _panel(parent: Node, preset: Control.LayoutPreset, margins: Vector4) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(preset)
	panel.offset_left = margins.x
	panel.offset_top = margins.y
	panel.offset_right = margins.z
	panel.offset_bottom = margins.w
	panel.add_theme_stylebox_override("panel", _style(Color("#101b21f5"), Color("#394749"), 12))
	return panel


func _build_ui_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_map = Control.new()
	layer.add_child(_map)
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.draw.connect(_draw_routes)
	for r in _game_data.regions:
		var id: String = r.id
		var pin := _button(_map, r.name, _pick_region.bind(id))
		pin.size = PIN_SIZE
		pin.tooltip_text = r.coverage
		pin.add_theme_font_size_override("font_size", 15)
		_pins[id] = pin
		var bar := ProgressBar.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", _style(Color("#24353a"), Color.TRANSPARENT, 0))
		bar.add_theme_stylebox_override("fill", _style(CYAN, Color.TRANSPARENT, 0))
		pin.add_child(bar)
		bar.position = Vector2(8, 40)
		bar.size = Vector2(PIN_SIZE.x - 16, 4)
		_bars[id] = bar

	var top_panel := _panel(layer, Control.PRESET_TOP_WIDE, Vector4(12, 10, -12, 62))
	var top := HBoxContainer.new()
	top_panel.add_child(top)
	top.add_theme_constant_override("separation", 16)
	_label(top, "大秦  /  2076", 22, GOLD)
	_lbl_act = _label(top, "", 16, Color.WHITE)
	_lbl_morale = _label(top, "", 16, CYAN)
	_lbl_conquest = _label(top, "", 16, Color.WHITE)
	_lbl_patience = _label(top, "", 16, MUTED)
	_lbl_patience.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(top, "切换视角", _toggle_camera)
	_btn_pool = _button(top, "完整池", _toggle_pool)
	_button(top, "重开", _restart)

	var term := _panel(layer, Control.PRESET_RIGHT_WIDE, Vector4(-342, 80, -12, -12))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 9)
	term.add_child(tv)
	_label(tv, "军令终端", 24, GOLD)
	_lbl_actions = _label(tv, "", 15, MUTED)
	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 8)
	tv.add_child(_cards_box)
	_btn_refresh = _button(tv, "", func(): _cancel_aim(); _result(core.refresh_terminal()))
	_btn_fleet = _button(tv, "", func(): _cancel_aim(); _result(core.build_fleet()))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tv.add_child(spacer)
	_button(tv, "结束回合  →", func(): _cancel_aim(); _result(core.end_turn()))

	var bottom := _panel(layer, Control.PRESET_BOTTOM_WIDE, Vector4(12, -147, -354, -12))
	var bv := VBoxContainer.new()
	bottom.add_child(bv)
	var row := HBoxContainer.new()
	bv.add_child(row)
	_detail = _label(row, "", 17, GOLD)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack = _button(row, "常规进攻", func(): _result(core.conventional_attack(_selected)))
	_cancel = _button(row, "取消瞄准", _cancel_aim)
	_lbl_banter = _label(bv, "", 15, MUTED)
	_report = _label(bv, "", 16, CYAN)
	_hidden_box = HBoxContainer.new()
	bv.add_child(_hidden_box)
	_modal_shade = ColorRect.new()
	layer.add_child(_modal_shade)
	_modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_shade.color = Color(0.02, 0.04, 0.06, 0.66)
	_modal_shade.hide()

	# 突发事件弹窗
	_event_panel = PanelContainer.new()
	_event_panel.set_anchors_preset(Control.PRESET_CENTER)
	_event_panel.offset_left = -240; _event_panel.offset_top = -120; _event_panel.offset_right = 240; _event_panel.offset_bottom = 120
	_event_panel.visible = false
	layer.add_child(_event_panel)
	var ev_box := VBoxContainer.new(); _event_panel.add_child(ev_box)
	_event_title = Label.new(); ev_box.add_child(_event_title)
	_event_desc = Label.new(); _event_desc.autowrap_mode = TextServer.AUTOWRAP_WORD; ev_box.add_child(_event_desc)
	_event_btn_a = Button.new(); _event_btn_a.pressed.connect(func(): _event_panel.visible = false; core.resolve_event("A")); ev_box.add_child(_event_btn_a)
	_event_btn_b = Button.new(); _event_btn_b.pressed.connect(func(): _event_panel.visible = false; core.resolve_event("B")); ev_box.add_child(_event_btn_b)

	# 结局弹窗
	_ending_panel = PanelContainer.new()
	_ending_panel.set_anchors_preset(Control.PRESET_CENTER)
	_ending_panel.offset_left = -250; _ending_panel.offset_top = -110; _ending_panel.offset_right = 250; _ending_panel.offset_bottom = 110
	_ending_panel.visible = false
	layer.add_child(_ending_panel)
	var end_box := VBoxContainer.new(); _ending_panel.add_child(end_box)
	_ending_title = Label.new(); end_box.add_child(_ending_title)
	_ending_desc = Label.new(); _ending_desc.autowrap_mode = TextServer.AUTOWRAP_WORD; end_box.add_child(_ending_desc)
	var end_re := Button.new(); end_re.text = "再开一局"; end_re.pressed.connect(_restart); end_box.add_child(end_re)


func _frame_map() -> void:
	var view := get_viewport().get_visible_rect().size
	var scale_px := minf((view.x - 375.0) / 14.8, (view.y - 235.0) / 8.5)
	camera.size = view.y / maxf(1, scale_px)
	var pitch := -65.0 if _camera_mode == "sandtable" else -45.0
	camera.rotation_degrees = Vector3(pitch, 0, 0)
	var center := Vector3(171.0 / scale_px, 0, 36.0 / scale_px)
	camera.position = center + camera.basis.z * 13
	_place_pins()


func _toggle_camera() -> void:
	_camera_mode = "terminal" if _camera_mode == "sandtable" else "sandtable"
	var old_pos := camera.position
	var old_rot := camera.rotation
	_frame_map()
	var pos := camera.position
	var rot := camera.rotation
	camera.position = old_pos
	camera.rotation = old_rot
	if _camera_tween:
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.tween_property(camera, "position", pos, 0.45)
	_camera_tween.parallel().tween_property(camera, "rotation", rot, 0.45)
	_camera_tween.tween_callback(_place_pins)


func _process(_delta: float) -> void:
	if _camera_tween and _camera_tween.is_running():
		_place_pins()


func _place_pins() -> void:
	for id in _pins:
		var pin: Button = _pins[id]
		pin.position = (camera.unproject_position(_region_pos[id]) + Vector2(PIN_OFFSETS[id])).round()
	_map.queue_redraw()


func _draw_routes() -> void:
	if _latest.is_empty():
		return
	var capital := Vector3(3.64, 0.12, -0.71)
	for r in _latest.regions:
		var site := camera.unproject_position(_region_pos[r.id])
		var pin: Button = _pins[r.id]
		var center := pin.get_rect().get_center()
		var color := _pin_color(r)
		if r.conquered:
			var origin: Vector3 = _region_pos.get(r.prereq, capital)
			_map.draw_line(camera.unproject_position(origin), site, Color(GOLD, 0.8), 2, true)
			_map.draw_circle(site, 25, Color(GOLD, 0.22))
		_map.draw_line(site, center, Color(color, 0.7), 1.5, true)
		_map.draw_circle(site, 6, color)
		_map.draw_arc(site, 11, 0, TAU, 28, color, 1.5, true)


func _unhandled_input(event: InputEvent) -> void:
	if _modal_shade.visible:
		return
	if _pending_cheat_slot >= 0 and event.is_action_pressed("ui_cancel"):
		_cancel_aim()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for id in _region_pos:
			if camera.unproject_position(_region_pos[id]).distance_to(event.position) <= 27:
				_pick_region(id)
				get_viewport().set_input_as_handled()
				return


func _restart() -> void:
	_pending_cheat_slot = -1
	_selected = ""
	_report.text = ""
	_ending_panel.hide()
	_event_panel.hide()
	_modal_shade.hide()
	core.init_game(_game_data, _lines_data, _mvp_only)


func _toggle_pool() -> void:
	_mvp_only = not _mvp_only
	_btn_pool.text = "精简池" if _mvp_only else "完整池"
	_restart()


func _on_state_changed(snap: Dictionary) -> void:
	_latest = snap
	_modal_shade.visible = not snap.pending_event.is_empty() or snap.game_over_code != ""
	_lbl_act.text = "第 %d 回合 · 第 %d 幕" % [snap["turn"], snap["act"]]
	_lbl_morale.text = "民心: %d/%d" % [snap["morale"], snap["morale_cap"]]
	_lbl_conquest.text = "统一: %d/6" % snap["conquered_count"]
	_lbl_patience.text = "始皇耐心: %d" % snap["patience"]
	_lbl_actions.text = "行动 %s  %d/2　·　进攻 %d/1" % ["●".repeat(snap["actions_left"]) + "○".repeat(2 - snap["actions_left"]), snap["actions_left"], snap["attack_left"]]

	# 青铜鼎火光随民心实时变化
	var low: bool = int(snap["morale"]) < 40
	_cauldron_light.light_color = Color("#FF2A2A") if low else Color("#FFB347")
	_cauldron_light.light_energy = 1.2 + float(snap["morale"]) / 45.0

	# 更新 3D 板块信标染黑状态与悬浮标牌
	var occupied := PackedFloat32Array()
	for r in snap["regions"]:
		occupied.append(1.0 if r.conquered else 0.0)
		var rid: String = r["id"]
		var m: MeshInstance3D = _region_meshes.get(rid)
		if m and m.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = m.material_override
			mat.albedo_color = Color("#0B0D10") if r["conquered"] else Color("#2C2620")
			mat.emission = Color("#FFB347") if r["conquered"] else (Color("#00F0FF") if _pending_cheat_slot >= 0 else Color("#5c4c3b"))
			mat.emission_energy_multiplier = 0.85 if r["conquered"] else (1.1 if _pending_cheat_slot >= 0 else 0.4)

	occupied.append(0.0) # Xianyang is already highlighted on the original map.
	_map_material.set_shader_parameter("occupied", occupied)

	# 更新 3D 全息名臣立绘（支持全部 9 位名臣）
	var advs: Array = snap["advisors"]
	for i in range(2):
		var sp := _holo_sprites[i]
		if i < advs.size():
			var p_path: String = advs[i].get("portrait", "")
			if p_path != "" and ResourceLoader.exists(p_path):
				var tex: Texture2D = load(p_path)
				sp.texture = tex
				(sp.material_override as ShaderMaterial).set_shader_parameter("albedo_tex", tex)
			sp.visible = true
		else:
			sp.visible = false

	# 更新隐藏关 3D 微光点与按钮
	for ch in _hidden_box.get_children():
		ch.queue_free()
	var hvis: Dictionary = snap["hidden_visible"]
	for hid in hvis.keys():
		if _hidden_nodes.has(hid):
			_hidden_nodes[hid].visible = bool(hvis[hid])
		if bool(hvis[hid]):
			var hb := Button.new()
			hb.text = "探索 · " + str({"penglai":"蓬莱仙岛", "dazexiang":"大泽乡", "antarctica":"南极时间舱"}.get(hid, hid))
			hb.pressed.connect(func(): _cancel_aim(); _result(core.trigger_hidden(hid)))
			_hidden_box.add_child(hb)

	_refresh_commands()


func _refresh_commands() -> void:
	for child in _cards_box.get_children():
		_cards_box.remove_child(child)
		child.queue_free()
	for i in range(_latest.terminal_cards.size()):
		_add_card(i)
	_btn_refresh.text = "刷新  %d/3　·　民心 −%d" % [_latest.refreshes_left, core.get_refresh_cost()]
	_btn_refresh.disabled = _latest.refreshes_left <= 0 or _latest.overheat_no_refresh
	_btn_fleet.text = "航线已开通" if _latest.sea_unlocked else "征造楼船　·　民心 −%d" % core.get_fleet_cost()
	_btn_fleet.disabled = _latest.sea_unlocked or _latest.actions_left <= 0
	_refresh_map()


func _add_card(slot: int) -> void:
	var card: Dictionary = _latest.terminal_cards[slot]
	var data: Dictionary = card.data
	var advisor: bool = card.kind == "advisor"
	var kind: String = "名臣" if advisor else {"military":"军事", "livelihood":"民生", "blacktech":"奇术"}[data.category]
	var tint: Color = {"军事":CYAN, "民生":Color("#aace94"), "奇术":Color("#c6afd9"), "名臣":GOLD}[kind]
	var delta := -core.get_effective_advisor_cost(data) if advisor else core.get_effective_cheat_delta(data)
	if delta < 0 and _latest.cyber_burn_turns > 0:
		delta = 0
	var price := "民心 %+d" % delta if delta != 0 else "免民心"
	var button := _button(_cards_box, "", _use_card.bind(slot))
	button.custom_minimum_size.y = 108
	button.disabled = card.bought or _latest.actions_left <= 0 or (data.id == "education" and _latest.attack_left <= 0)
	var active := slot == _pending_cheat_slot
	var face := _style(Color("#183237") if active else Color("#19272e"), tint if active else Color("#374a50"), 0)
	face.border_width_left = 3
	face.border_color = tint.darkened(0.15)
	button.add_theme_stylebox_override("normal", face)
	var body := VBoxContainer.new()
	button.add_child(body)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 12
	body.offset_right = -10
	body.offset_top = 6
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scope := "入列" if advisor else ("点选目标" if data.needs_target else "即刻生效")
	var state := "已部署" if card.bought else ("瞄准中" if active else scope)
	var terms := "%s　/　%s" % [kind, state]
	if not card.bought:
		terms += "　·　" + price
	var meta := _label(body, terms, 13, tint)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(title_row)
	if advisor:
		var portrait := TextureRect.new()
		portrait.texture = load(data.portrait)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(28, 28)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_row.add_child(portrait)
	_label(title_row, data.name, 19, Color.WHITE).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var description: String = data.skill if advisor else data.desc
	if not advisor and data.needs_target:
		var punch := "直接攻克" if data.id == "nuke_seal" or (data.id == "drone" and core.has_advisor("huoqubing")) else "%d 伤害" % _card_damage(data, 0)
		description = "任选未占领地区 · " + punch
		if data.id == "ironclad":
			description += "，开通航线"
	var line := _label(body, description, 14, MUTED)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.tooltip_text = description + "（消耗 1 行动）"
	if button.disabled:
		body.modulate = Color("#a5a7a7")


func _card_damage(data: Dictionary, hp: int) -> int:
	if data.id == "nuke_seal" or (data.id == "drone" and core.has_advisor("huoqubing")):
		return hp
	return int(data.damage) * (2 if core.has_advisor("caocao") else 1)


func _use_card(slot: int) -> void:
	if _modal_shade.visible:
		return
	var card: Dictionary = _latest.terminal_cards[slot]
	if card.kind == "cheat" and card.data.needs_target:
		_pending_cheat_slot = -1 if _pending_cheat_slot == slot else slot
		_refresh_commands()
		return
	_pending_cheat_slot = -1
	if card.kind == "advisor":
		_result(core.summon_advisor(slot, 0 if core.advisors.size() >= 2 else -1))
	else:
		_result(core.buy_cheat(slot))


func _cancel_aim() -> void:
	if _pending_cheat_slot != -1:
		_pending_cheat_slot = -1
		_refresh_commands()


func _pick_region(id: String) -> void:
	if _modal_shade.visible:
		return
	_selected = id
	if _pending_cheat_slot >= 0:
		var slot := _pending_cheat_slot
		_pending_cheat_slot = -1
		var res := core.buy_cheat(slot, id)
		if not res.ok:
			_pending_cheat_slot = slot
			_result(res)
		_refresh_commands()
	else:
		_refresh_map()


func _pin_color(r: Dictionary) -> Color:
	if r.conquered:
		return GOLD
	if _pending_cheat_slot >= 0 or core.can_attack_region(r.id):
		return CYAN
	return MUTED


func _refresh_map() -> void:
	_attack.hide()
	_cancel.visible = _pending_cheat_slot >= 0
	_detail.text = "选择战区"
	_lbl_banter.text = "点选地图据点，查看守军与进攻条件。"
	if _latest.turn == 1 and _latest.conquered_count == 0:
		_lbl_banter.text = "北方草原仅有 15 守军，可在此发起首次常规进攻。"
	for r in _latest.regions:
		var pin: Button = _pins[r.id]
		var bar: ProgressBar = _bars[r.id]
		var tint := _pin_color(r)
		pin.text = ("◆ " if r.conquered else "") + str(r.name)
		pin.add_theme_color_override("font_color", tint)
		pin.add_theme_stylebox_override("normal", _style(Color("#20383d") if r.id == _selected else Color("#111d23f0"), tint if r.id == _selected or r.conquered else tint.darkened(0.5), 3))
		bar.max_value = r.max_hp
		bar.value = r.hp
		pin.tooltip_text = "%s　·　守军 %d/%d" % [r.coverage, r.hp, r.max_hp]
		if _pending_cheat_slot >= 0 and not r.conquered:
			var payload: Dictionary = _latest.terminal_cards[_pending_cheat_slot].data
			var damage := _card_damage(payload, int(r.hp))
			pin.tooltip_text += "　→　%d（命中后）" % maxi(0, int(r.hp) - damage)
		if r.id != _selected:
			continue
		_detail.text = "%s　·　%s" % [r.name, "已纳入秦疆" if r.conquered else "守军 %d/%d" % [r.hp, r.max_hp]]
		_lbl_banter.text = r.reward
		if not r.conquered:
			_attack.show()
			var ready := core.can_attack_region(r.id)
			_attack.disabled = not ready or _latest.attack_left <= 0 or _latest.education_turn
			var eff := 1.0 if r.id == "south_asia" and _latest.penicillin_turn else float(r.efficiency)
			_attack.text = "进攻　·　%d 伤害" % floori(eff * _latest.conventional_power)
			if not ready:
				_lbl_banter.text = "须先开通渡海航线。" if r.requires_sea else "须先攻克%s。" % _pins[r.prereq].text
			elif _latest.education_turn:
				_lbl_banter.text = "本回合已推行义务教育，无法常规进攻。"
			elif _latest.attack_left <= 0:
				_lbl_banter.text = "本回合常规进攻已用完，可部署军事卡。"
	if _pending_cheat_slot >= 0:
		_attack.hide()
		_detail.text = "瞄准　/　" + str(_latest.terminal_cards[_pending_cheat_slot].data.name)
		_lbl_banter.text = "点击任一未占领据点立即打击。Esc 取消。"
	_map.queue_redraw()


func _result(res: Dictionary) -> void:
	if not res.get("ok", false):
		_report.text = res.get("error", "操作未完成")


func _on_strike_performed(region_id: String, damage: int, source: String, conquered: bool) -> void:
	_spawn_strike_fx(region_id, conquered)
	var pin: Button = _pins[region_id]
	var region: Dictionary = _latest.regions.filter(func(r): return r.id == region_id)[0]
	var loss := mini(damage, int(region.hp))
	var hit := _label(_map, "−%d%s" % [loss, "　攻克" if conquered else ""], 24, GOLD if conquered else CYAN)
	hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit.add_theme_constant_override("outline_size", 5)
	hit.add_theme_color_override("font_outline_color", Color("#0c191f"))
	hit.position = pin.position - Vector2(0, 26)
	var tween := hit.create_tween()
	tween.tween_property(hit, "position:y", hit.position.y - 30, 0.5)
	tween.tween_interval(0.45)
	tween.tween_property(hit, "modulate:a", 0.0, 0.3)
	tween.tween_callback(hit.queue_free)
	_report.text = "%s击中%s　−%d　·　%s" % [source, region.name, loss, "已纳入秦疆" if conquered else "守军剩余 %d" % (int(region.hp) - loss)]


func _on_advisor_spoke(_aid: String, advisor_name: String, line: String) -> void:
	_report.text = "【%s】「%s」" % [advisor_name, line]


func _on_hidden_triggered(hidden_id: String, reward_text: String) -> void:
	_report.text = "✦ 触发隐藏关【%s】：%s" % [hidden_id, reward_text]


func _on_event_triggered(ev: Dictionary) -> void:
	_event_title.text = ev["title"]
	_event_desc.text = ev["desc"]
	_event_btn_a.text = "A. %s" % ev["option_a"]["label"]
	_event_btn_b.text = "B. %s" % ev["option_b"]["label"]
	_event_panel.visible = true


func _on_game_ended(code: String, data: Dictionary) -> void:
	_ending_title.text = "%s (%s)" % [data.get("title", "终局"), code]
	_ending_desc.text = data.get("prompt", "")
	_ending_panel.visible = true
