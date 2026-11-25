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
const CRIMSON := Color("#ff4d4d")
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
var _cauldron_flame: MeshInstance3D
var _flame_time: float = 0.0

# 音频系统
var _audio_muted: bool = false
var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _sfx_bank: Dictionary = {}

# 交互状态
var _pending_cheat_slot: int = -1
var _pending_replace_card_slot: int = -1
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
var _btn_mute: Button
var _cards_box: VBoxContainer
var _advisors_box: HBoxContainer
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
var _replace_panel: PanelContainer
var _replace_title: Label
var _replace_desc: Label
var _replace_btn_0: Button
var _replace_btn_1: Button


func _ready() -> void:
	_game_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))
	_lines_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/lines.json"))

	_setup_audio()
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


func _setup_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = -14.0
	add_child(_bgm_player)
	if ResourceLoader.exists("res://assets/audio/bgm_ambient.wav"):
		_bgm_player.stream = load("res://assets/audio/bgm_ambient.wav")
		_bgm_player.finished.connect(func():
			if not _audio_muted and _bgm_player.stream != null:
				_bgm_player.play()
		)
		_bgm_player.play()

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.volume_db = -6.0
	add_child(_sfx_player)

	var names := {
		"click": "res://assets/audio/sfx_click.wav",
		"strike": "res://assets/audio/sfx_strike.wav",
		"conquer": "res://assets/audio/sfx_conquer.wav",
		"summon": "res://assets/audio/sfx_summon.wav",
		"event": "res://assets/audio/sfx_event.wav",
		"victory": "res://assets/audio/sfx_victory.wav",
		"defeat": "res://assets/audio/sfx_defeat.wav",
	}
	for k in names.keys():
		if ResourceLoader.exists(names[k]):
			_sfx_bank[k] = load(names[k])


func _play_sfx(key: String) -> void:
	if _audio_muted or not _sfx_bank.has(key):
		return
	_sfx_player.stream = _sfx_bank[key]
	_sfx_player.play()


func _toggle_mute() -> void:
	if _bgm_player == null:
		return
	_audio_muted = not _audio_muted
	_btn_mute.text = "静音中" if _audio_muted else "音效开"
	if _audio_muted:
		_bgm_player.stop()
		_sfx_player.stop()
	elif _bgm_player.stream != null:
		_bgm_player.play()


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

	# 3. 全球 6 大板块全息信标盘
	for r in _game_data.get("regions", []):
		var p: Array = r["pos3d"]
		var pos := Vector3(p[0], 0.04, p[2])
		var beacon := _make_beacon(pos, 0.16, 0.05, Color("#2C2620"), Color("#00F0FF"))
		add_child(beacon)
		_region_meshes[r["id"]] = beacon
		_region_pos[r["id"]] = pos

	# 4. 桌角青铜鼎实体 + 脉动民心火光
	var cauldron_base := _make_beacon(Vector3(-6.35, 0.24, 3.15), 0.44, 0.48, Color("#3a2e22"), Color("#6b4a1f"))
	add_child(cauldron_base)
	var cauldron_rim := _make_beacon(Vector3(-6.35, 0.5, 3.15), 0.5, 0.08, Color("#2C2620"), Color("#FFB347"))
	add_child(cauldron_rim)
	_cauldron_flame = MeshInstance3D.new()
	var fmesh := SphereMesh.new()
	fmesh.radius = 0.24
	fmesh.height = 0.52
	_cauldron_flame.mesh = fmesh
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color("#FFB347")
	fmat.emission_enabled = true
	fmat.emission = Color("#FFB347")
	fmat.emission_energy_multiplier = 2.8
	_cauldron_flame.material_override = fmat
	_cauldron_flame.position = Vector3(-6.35, 0.72, 3.15)
	add_child(_cauldron_flame)

	_cauldron_light = OmniLight3D.new()
	_cauldron_light.position = Vector3(-6.35, 1.45, 3.15)
	_cauldron_light.light_color = Color("#FFB347")
	_cauldron_light.light_energy = 2.4
	_cauldron_light.omni_range = 13.0
	add_child(_cauldron_light)

	# 5. 沙盘北侧高台秦始皇御座剪影（暗玄黑+微弱鎏金背光）
	var dais := _make_block(Vector3(0.0, 0.14, -4.48), Vector3(2.8, 0.28, 0.8), Color("#12100E"), Color("#4a371c"))
	add_child(dais)
	var throne := _make_block(Vector3(0.0, 0.95, -4.62), Vector3(1.15, 1.5, 0.28), Color("#08090C"), Color("#2C2620"))
	add_child(throne)
	var emperor := _make_beacon(Vector3(0.0, 0.82, -4.42), 0.34, 1.15, Color("#050608"), Color("#704e1e"))
	add_child(emperor)

	# 6. 沙盘北缘 2 个 AI 名臣全息投影位（面向正交镜头，避免被裁切）
	var shader: Shader = load("res://shaders/hologram.gdshader")
	for x_pos in [-2.65, 2.65]:
		var sp := Sprite3D.new()
		sp.position = Vector3(x_pos, 0.85, -4.18)
		sp.pixel_size = 0.0044
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
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
	button.add_theme_stylebox_override("pressed", _style(Color("#0f1b20"), GOLD, 6))
	button.add_theme_stylebox_override("disabled", _style(Color("#121a1e"), Color("#273437"), 6))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _panel(parent: Node, preset: Control.LayoutPreset, margins: Vector4, border: Color = Color("#394749"), pad: int = 12) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(preset)
	panel.offset_left = margins.x
	panel.offset_top = margins.y
	panel.offset_right = margins.z
	panel.offset_bottom = margins.w
	panel.add_theme_stylebox_override("panel", _style(Color("#101b21f5"), border, pad))
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

	# 顶部状态栏
	var top_panel := _panel(layer, Control.PRESET_TOP_WIDE, Vector4(12, 10, -12, 62))
	var top := HBoxContainer.new()
	top_panel.add_child(top)
	top.add_theme_constant_override("separation", 14)
	_label(top, "大秦  /  2076", 22, GOLD)
	_lbl_act = _label(top, "", 16, Color.WHITE)
	_lbl_morale = _label(top, "", 16, CYAN)
	_lbl_conquest = _label(top, "", 16, Color.WHITE)
	_lbl_patience = _label(top, "", 16, MUTED)
	_lbl_patience.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_mute = _button(top, "音效开", _toggle_mute)
	_button(top, "切换视角", _toggle_camera)
	_btn_pool = _button(top, "完整池", _toggle_pool)
	_button(top, "重开", func(): _play_sfx("click"); _restart())

	# 左上角在场名臣常驻槽位（2 席）
	var adv_panel := _panel(layer, Control.PRESET_TOP_LEFT, Vector4(12, 72, 376, 134), Color("#3b4d52"), 8)
	_advisors_box = HBoxContainer.new()
	_advisors_box.add_theme_constant_override("separation", 10)
	adv_panel.add_child(_advisors_box)

	# 右侧军令终端
	var term := _panel(layer, Control.PRESET_RIGHT_WIDE, Vector4(-342, 72, -12, -12))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 9)
	term.add_child(tv)
	_label(tv, "军令终端", 24, GOLD)
	_lbl_actions = _label(tv, "", 15, MUTED)
	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 8)
	tv.add_child(_cards_box)
	_btn_refresh = _button(tv, "", func(): _play_sfx("click"); _cancel_aim(); _result(core.refresh_terminal()))
	_btn_fleet = _button(tv, "", func(): _play_sfx("click"); _cancel_aim(); _result(core.build_fleet()))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tv.add_child(spacer)
	_button(tv, "结束回合  →", func(): _play_sfx("click"); _cancel_aim(); _result(core.end_turn()))

	# 底部战区详情与战报栏
	var bottom := _panel(layer, Control.PRESET_BOTTOM_WIDE, Vector4(12, -147, -354, -12))
	var bv := VBoxContainer.new()
	bottom.add_child(bv)
	var row := HBoxContainer.new()
	bv.add_child(row)
	_detail = _label(row, "", 17, GOLD)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack = _button(row, "常规进攻", func(): _play_sfx("click"); _result(core.conventional_attack(_selected)))
	_cancel = _button(row, "取消瞄准", func(): _play_sfx("click"); _cancel_aim())
	_lbl_banter = _label(bv, "", 15, MUTED)
	_report = _label(bv, "", 16, CYAN)
	_hidden_box = HBoxContainer.new()
	_hidden_box.add_theme_constant_override("separation", 8)
	bv.add_child(_hidden_box)

	# 模态弹窗半透明遮罩
	_modal_shade = ColorRect.new()
	layer.add_child(_modal_shade)
	_modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_shade.color = Color(0.02, 0.04, 0.06, 0.68)
	_modal_shade.hide()

	# 突发事件弹窗（暗青金统一视觉）
	_event_panel = _panel(layer, Control.PRESET_CENTER, Vector4(-260, -145, 260, 145), GOLD, 18)
	_event_panel.visible = false
	var ev_box := VBoxContainer.new()
	ev_box.add_theme_constant_override("separation", 10)
	_event_panel.add_child(ev_box)
	_label(ev_box, "突发急报  /  历史 × 科技", 13, CYAN)
	_event_title = _label(ev_box, "", 21, GOLD)
	_event_desc = _label(ev_box, "", 15, Color("#dbe6e6"))
	_event_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_event_btn_a = _button(ev_box, "", func(): _play_sfx("click"); _event_panel.visible = false; core.resolve_event("A"))
	_event_btn_b = _button(ev_box, "", func(): _play_sfx("click"); _event_panel.visible = false; core.resolve_event("B"))

	# 结局弹窗（暗青金统一视觉）
	_ending_panel = _panel(layer, Control.PRESET_CENTER, Vector4(-270, -135, 270, 135), GOLD, 20)
	_ending_panel.visible = false
	var end_box := VBoxContainer.new()
	end_box.add_theme_constant_override("separation", 12)
	_ending_panel.add_child(end_box)
	_label(end_box, "大秦终局档案", 13, CYAN)
	_ending_title = _label(end_box, "", 24, GOLD)
	_ending_desc = _label(end_box, "", 16, Color("#e4efef"))
	_ending_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_button(end_box, "再开一局", func(): _play_sfx("click"); _restart())

	# 满员替换名臣弹窗
	_replace_panel = _panel(layer, Control.PRESET_CENTER, Vector4(-260, -145, 260, 145), CYAN, 18)
	_replace_panel.visible = false
	var rep_box := VBoxContainer.new()
	rep_box.add_theme_constant_override("separation", 10)
	_replace_panel.add_child(rep_box)
	_label(rep_box, "名臣席位已满（上限 2 位）", 13, CYAN)
	_replace_title = _label(rep_box, "", 20, GOLD)
	_replace_desc = _label(rep_box, "请选择要离场的名臣席位：", 15, MUTED)
	_replace_btn_0 = _button(rep_box, "", _confirm_replace.bind(0))
	_replace_btn_1 = _button(rep_box, "", _confirm_replace.bind(1))
	_button(rep_box, "取消召唤", _cancel_replace)


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
	_play_sfx("click")
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


func _process(delta: float) -> void:
	if _camera_tween and _camera_tween.is_running():
		_place_pins()
	# 青铜鼎火光柔和脉动
	if _cauldron_flame != null:
		_flame_time += delta * 4.2
		var pulse := 1.0 + 0.08 * sin(_flame_time)
		_cauldron_flame.scale = Vector3(pulse, 1.0 + 0.14 * cos(_flame_time * 1.3), pulse)


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
	if _replace_panel.visible and event.is_action_pressed("ui_cancel"):
		_cancel_replace()
		get_viewport().set_input_as_handled()
		return
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
	_pending_replace_card_slot = -1
	_selected = ""
	_report.text = ""
	_ending_panel.hide()
	_event_panel.hide()
	_replace_panel.hide()
	_modal_shade.hide()
	core.init_game(_game_data, _lines_data, _mvp_only)


func _toggle_pool() -> void:
	_play_sfx("click")
	_mvp_only = not _mvp_only
	_btn_pool.text = "精简池" if _mvp_only else "完整池"
	_restart()


func _sync_modal_shade() -> void:
	_modal_shade.visible = (
		_event_panel.visible
		or _ending_panel.visible
		or _replace_panel.visible
		or (not _latest.is_empty() and (not _latest.pending_event.is_empty() or _latest.game_over_code != ""))
	)


func _on_state_changed(snap: Dictionary) -> void:
	_latest = snap
	_sync_modal_shade()
	_lbl_act.text = "第 %d 回合 · 第 %d 幕" % [snap["turn"], snap["act"]]
	var low: bool = int(snap["morale"]) < 40
	_lbl_morale.text = ("%s民心: %d/%d" % ["⚠ " if low else "", snap["morale"], snap["morale_cap"]])
	_lbl_morale.modulate = CRIMSON if low else CYAN
	_lbl_conquest.text = "统一: %d/6" % snap["conquered_count"]
	_lbl_patience.text = "始皇耐心: %d" % snap["patience"]
	_lbl_actions.text = "行动 %s  %d/2　·　进攻 %d/1" % ["●".repeat(snap["actions_left"]) + "○".repeat(2 - snap["actions_left"]), snap["actions_left"], snap["attack_left"]]

	# 青铜鼎火光与火芯随民心实时变化
	var flame_col := Color("#FF2A2A") if low else Color("#FFB347")
	_cauldron_light.light_color = flame_col
	_cauldron_light.light_energy = 1.2 + float(snap["morale"]) / 45.0
	if _cauldron_flame and _cauldron_flame.material_override is StandardMaterial3D:
		var fm: StandardMaterial3D = _cauldron_flame.material_override
		fm.albedo_color = flame_col
		fm.emission = flame_col
		fm.emission_energy_multiplier = 3.4 if low else (1.5 + float(snap["morale"]) / 40.0)

	# 更新 3D 板块信标染黑状态与地图着色器
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

	# 更新 3D 全息名臣立绘 & 左上角 2D 在场名臣槽位
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
	_refresh_advisor_bar(advs)

	# 更新隐藏关 3D 微光点与按钮
	for ch in _hidden_box.get_children():
		ch.queue_free()
	var hvis: Dictionary = snap["hidden_visible"]
	for hid in hvis.keys():
		if _hidden_nodes.has(hid):
			_hidden_nodes[hid].visible = bool(hvis[hid])
		if bool(hvis[hid]):
			var label_txt := "✦ 探索 · " + str({"penglai":"蓬莱仙岛", "dazexiang":"大泽乡", "antarctica":"南极时间舱"}.get(hid, hid))
			var hb := _button(_hidden_box, label_txt, func(): _play_sfx("click"); _cancel_aim(); _result(core.trigger_hidden(hid)))
			hb.add_theme_color_override("font_color", GOLD)

	_refresh_commands()


func _refresh_advisor_bar(advs: Array) -> void:
	for ch in _advisors_box.get_children():
		_advisors_box.remove_child(ch)
		ch.queue_free()
	for i in range(2):
		var slot_box := PanelContainer.new()
		slot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var has_adv := i < advs.size()
		slot_box.add_theme_stylebox_override("panel", _style(Color("#15242a") if has_adv else Color("#0e171c"), GOLD if has_adv else Color("#2b3a3e"), 5))
		_advisors_box.add_child(slot_box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		slot_box.add_child(row)
		if has_adv:
			var adv: Dictionary = advs[i]
			var p_path: String = adv.get("portrait", "")
			if p_path != "" and ResourceLoader.exists(p_path):
				var tex_rect := TextureRect.new()
				tex_rect.texture = load(p_path)
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.custom_minimum_size = Vector2(34, 34)
				row.add_child(tex_rect)
			var txt := VBoxContainer.new()
			txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(txt)
			_label(txt, "%d号席 · %s" % [i + 1, adv["name"]], 14, GOLD)
			var sk := _label(txt, str(adv["skill"]).substr(0, 12) + "…", 11, MUTED)
			sk.clip_text = true
			slot_box.tooltip_text = "【%s】%s" % [adv["name"], adv["skill"]]
		else:
			var empty_lbl := _label(row, "名臣 %d 号席 · 空" % (i + 1), 13, Color("#607376"))
			empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot_box.tooltip_text = "可在右侧终端召唤历史名臣入列（最多同时在场 2 位）"


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
	var is_free_hook: bool = (not card.bought) and bool(_latest.get("free_hook_available", false)) and (advisor or data.id == "drone")
	var delta := -core.get_effective_advisor_cost(data) if advisor else core.get_effective_cheat_delta(data)
	if delta < 0 and _latest.cyber_burn_turns > 0:
		delta = 0
	var price := "★ 首回合免费" if is_free_hook else ("民心 %+d" % delta if delta != 0 else "免民心")
	var button := _button(_cards_box, "", _use_card.bind(slot))
	button.custom_minimum_size.y = 108
	button.disabled = card.bought or _latest.actions_left <= 0 or (data.id == "education" and _latest.attack_left <= 0)
	var active := slot == _pending_cheat_slot
	var border_col := GOLD if is_free_hook else (tint if active else Color("#374a50"))
	var face := _style(Color("#183237") if active else (Color("#1d2a2d") if is_free_hook else Color("#19272e")), border_col, 0)
	face.border_width_left = 3
	face.border_color = GOLD if is_free_hook else tint.darkened(0.15)
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
	var meta := _label(body, terms, 13, GOLD if is_free_hook else tint)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(title_row)
	if advisor and ResourceLoader.exists(data.portrait):
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
	_play_sfx("click")
	var card: Dictionary = _latest.terminal_cards[slot]
	if card.kind == "cheat" and card.data.needs_target:
		_pending_cheat_slot = -1 if _pending_cheat_slot == slot else slot
		_refresh_commands()
		return
	_pending_cheat_slot = -1
	if card.kind == "advisor":
		if core.advisors.size() >= 2:
			_open_replace_dialog(slot, card.data)
		else:
			var res := core.summon_advisor(slot, -1)
			if res.get("ok", false):
				_play_sfx("summon")
			_result(res)
	else:
		_result(core.buy_cheat(slot))


func _open_replace_dialog(card_slot: int, incoming: Dictionary) -> void:
	_pending_replace_card_slot = card_slot
	_replace_title.text = "召唤【%s】入列" % incoming["name"]
	var a0: Dictionary = _latest.advisors[0]
	var a1: Dictionary = _latest.advisors[1]
	_replace_btn_0.text = "替换 1 号席：%s（%s）" % [a0["name"], str(a0["skill"]).substr(0, 18)]
	_replace_btn_1.text = "替换 2 号席：%s（%s）" % [a1["name"], str(a1["skill"]).substr(0, 18)]
	_replace_panel.visible = true
	_sync_modal_shade()


func _confirm_replace(replace_idx: int) -> void:
	_play_sfx("click")
	var slot := _pending_replace_card_slot
	_pending_replace_card_slot = -1
	_replace_panel.visible = false
	_sync_modal_shade()
	if slot >= 0:
		var res := core.summon_advisor(slot, replace_idx)
		if res.get("ok", false):
			_play_sfx("summon")
		_result(res)


func _cancel_replace() -> void:
	_play_sfx("click")
	_pending_replace_card_slot = -1
	_replace_panel.visible = false
	_sync_modal_shade()


func _cancel_aim() -> void:
	if _pending_cheat_slot != -1:
		_pending_cheat_slot = -1
		_refresh_commands()


func _pick_region(id: String) -> void:
	if _modal_shade.visible:
		return
	_play_sfx("click")
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
	if bool(_latest.get("free_hook_available", false)):
		_lbl_banter.text = "★ 首回合高光：右侧首次召唤【名臣】或部署【无人机蜂群】免民心！也可点北方草原发起免费常规进攻。"
	elif _latest.turn == 1 and _latest.conquered_count == 0:
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
	_play_sfx("conquer" if conquered else "strike")
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
	_play_sfx("summon")
	_report.text = "✦ 触发隐藏关【%s】：%s" % [hidden_id, reward_text]


func _on_event_triggered(ev: Dictionary) -> void:
	_play_sfx("event")
	_event_title.text = ev["title"]
	_event_desc.text = ev["desc"]
	_event_btn_a.text = "A. %s" % ev["option_a"]["label"]
	_event_btn_b.text = "B. %s" % ev["option_b"]["label"]
	_event_panel.visible = true
	_sync_modal_shade()


func _on_game_ended(code: String, data: Dictionary) -> void:
	_play_sfx("victory" if code.begins_with("win_") else "defeat")
	_ending_title.text = "%s (%s)" % [data.get("title", "终局"), code]
	_ending_desc.text = data.get("prompt", "")
	_ending_panel.visible = true
	_sync_modal_shade()
