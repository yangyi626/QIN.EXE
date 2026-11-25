extends Node3D
## 《大秦：2076》3D 玄黑沙盘主场景与 UI 表现层（v2.2 · 暗黑立体桌面重制版）
## 严格遵循逻辑与表现分离：仅调用 GameCore 公开方法并订阅信号，不反向篡改核心状态。

@onready var camera: Camera3D = $Camera3D

var core := GameCore.new()
var _game_data: Dictionary = {}
var _lines_data: Dictionary = {}
var _mvp_only: bool = false

# 调色板（玄黑 / 暗青铜 / 鎏金 / 赛博青 / 警报猩红）
const OBSIDIAN := Color("#0a0d11")
const GLASS_DARK := Color(0.045, 0.068, 0.085, 0.84)
const GOLD := Color("#f0be6e")
const CYAN := Color("#4df3ff")
const SAGE := Color("#8ee3a1")
const VIOLET := Color("#d0a6ff")
const CRIMSON := Color("#ff4242")
const MUTED := Color("#9fb3b5")
const XIANYANG_POS := Vector3(3.64, 0.08, -0.71)

# 3D 场景引用
var _region_meshes: Dictionary = {} # region_id -> MeshInstance3D (发光信标环)
var _region_pos: Dictionary = {}    # region_id -> Vector3
var _hidden_nodes: Dictionary = {}  # hidden_id -> MeshInstance3D
var _holo_sprites: Array[Sprite3D] = []
var _holo_rings: Array[MeshInstance3D] = []
var _holo_base_pos: Array[Vector3] = [Vector3(-3.15, 1.65, -4.35), Vector3(3.15, 1.65, -4.35)]
var _torch_left: OmniLight3D
var _torch_right: OmniLight3D
var _map_material := ShaderMaterial.new()
var _vignette_mat := ShaderMaterial.new()

# 相机透视、视差与震屏状态
var _camera_mode: String = "sandtable" # "sandtable" | "closeup"
var _cam_base_pos := Vector3(1.15, 6.25, 8.65)
var _cam_base_look := Vector3(0.85, -0.35, 0.2)
var _cam_cur_pos := Vector3(1.15, 6.25, 8.65)
var _cam_cur_look := Vector3(0.85, -0.35, 0.2)
var _mouse_norm := Vector2.ZERO
var _shake_strength: float = 0.0
var _anim_time: float = 0.0

# 音频系统
var _audio_muted: bool = false
var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _sfx_bank: Dictionary = {}

# 交互状态
var _latest: Dictionary = {}
var _prev_morale: int = 60
var _prev_patience: int = 12
var _selected: String = ""
var _hovered_region: String = ""
var _pending_cheat_slot: int = -1
var _pending_replace_card_slot: int = -1

# UI 节点引用
var _ui_root: Control
var _map_overlay: Control
var _pins: Dictionary = {}
var _bars: Dictionary = {}
var _popover: PanelContainer
var _pop_title: Label
var _pop_desc: Label
var _pop_attack: Button
var _lbl_act: Label
var _lbl_morale: Label
var _bar_morale: ProgressBar
var _lbl_conquest: Label
var _lbl_patience: Label
var _lbl_actions: Label
var _lbl_ticker: Label
var _btn_refresh: Button
var _btn_fleet: Button
var _btn_pool: Button
var _btn_mute: Button
var _btn_cancel_aim: Button
var _cards_box: VBoxContainer
var _advisors_box: HBoxContainer
var _hidden_box: HBoxContainer
var _bubbles: Array[PanelContainer] = []
var _bubble_labels: Array[Label] = []
var _bubble_timers: Array[float] = [0.0, 0.0]
var _modal_shade: ColorRect
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

	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 38.0
	_apply_camera_targets()
	_cam_cur_pos = _cam_base_pos
	_cam_cur_look = _cam_base_look
	camera.position = _cam_cur_pos
	camera.look_at(_cam_cur_look, Vector3.UP)
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
	_btn_mute.text = "静音" if _audio_muted else "音效"
	if _audio_muted:
		_bgm_player.stop()
		_sfx_player.stop()
	elif _bgm_player.stream != null:
		_bgm_player.play()


func _build_3d_sandtable() -> void:
	# 1. 玄黑立体桌面基座 + 鎏金嵌边（取代粗糙积木块）
	var table := MeshInstance3D.new()
	var table_mesh := BoxMesh.new()
	table_mesh.size = Vector3(14.8, 0.52, 8.65)
	table.mesh = table_mesh
	var table_mat := StandardMaterial3D.new()
	table_mat.albedo_color = Color("#12100e")
	table_mat.metallic = 0.65
	table_mat.roughness = 0.42
	table.material_override = table_mat
	table.position = Vector3(0, -0.32, 0)
	add_child(table)

	# 桌面四边微发光青铜鎏金嵌条
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color("#5a4424")
	trim_mat.metallic = 0.82
	trim_mat.roughness = 0.28
	trim_mat.emission_enabled = true
	trim_mat.emission = Color("#b87d32")
	trim_mat.emission_energy_multiplier = 0.45
	for rim in [
		[Vector3(0, -0.04, -4.08), Vector3(14.3, 0.06, 0.09)],
		[Vector3(0, -0.04, 4.08), Vector3(14.3, 0.06, 0.09)],
		[Vector3(-7.12, -0.04, 0), Vector3(0.09, 0.06, 8.25)],
		[Vector3(7.12, -0.04, 0), Vector3(0.09, 0.06, 8.25)],
	]:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = rim[1]
		bar.mesh = bm
		bar.material_override = trim_mat
		bar.position = rim[0]
		add_child(bar)

	# 1b. 咸阳宫大殿远景暗幕（直接融合 concept_xianyang.jpg 营造纵深）
	if ResourceLoader.exists("res://assets/textures/concept_xianyang.jpg"):
		var bg := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(27.0, 15.2)
		bg.mesh = qm
		var bg_mat := StandardMaterial3D.new()
		var bg_tex: Texture2D = load("res://assets/textures/concept_xianyang.jpg")
		bg_mat.albedo_texture = bg_tex
		bg_mat.albedo_color = Color(0.32, 0.29, 0.27, 1.0)
		bg_mat.emission_enabled = true
		bg_mat.emission_texture = bg_tex
		bg_mat.emission_energy_multiplier = 0.24
		bg_mat.roughness = 1.0
		bg.material_override = bg_mat
		bg.position = Vector3(0.5, 4.2, -10.4)
		add_child(bg)

	# 2. 世界地图发光沙盘面（16:9 + territory_map.gdshader 动态鎏金染色）
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
	sites.append(Vector2(0.5 + XIANYANG_POS.x / pmesh.size.x, 0.5 + XIANYANG_POS.z / pmesh.size.y))
	_map_material.set_shader_parameter("sites", sites)
	map_plane.material_override = _map_material
	map_plane.position = Vector3(0, -0.04, 0)
	add_child(map_plane)

	# 3. 咸阳本土鎏金信标环 + 6 大板块全息据点环
	var qin_ring := _make_ring(XIANYANG_POS, 0.28, 0.045, GOLD, 1.8)
	add_child(qin_ring)
	for r in _game_data.get("regions", []):
		var p: Array = r["pos3d"]
		var pos := Vector3(p[0], 0.03, p[2])
		var ring := _make_ring(pos, 0.24, 0.04, CYAN, 1.1)
		add_child(ring)
		_region_meshes[r["id"]] = ring
		_region_pos[r["id"]] = pos

	# 4. 氛围灯光：左侧暖金火炬（随民心变化） + 右侧赛博青终端背光
	_torch_left = OmniLight3D.new()
	_torch_left.position = Vector3(-6.8, 2.3, 2.5)
	_torch_left.light_color = Color("#ffaa44")
	_torch_left.light_energy = 2.6
	_torch_left.omni_range = 15.0
	add_child(_torch_left)

	_torch_right = OmniLight3D.new()
	_torch_right.position = Vector3(7.4, 2.0, 2.6)
	_torch_right.light_color = Color("#2be8ff")
	_torch_right.light_energy = 1.6
	_torch_right.omni_range = 12.0
	add_child(_torch_right)

	# 5. 沙盘对面 2 座名臣全息投影座环 + 羽化悬浮半身像
	var shader: Shader = load("res://shaders/hologram.gdshader")
	for i in range(2):
		var base_p: Vector3 = _holo_base_pos[i]
		var pad := _make_ring(Vector3(base_p.x, 0.04, base_p.z), 0.78, 0.045, CYAN, 1.25)
		pad.visible = false
		add_child(pad)
		_holo_rings.append(pad)

		var sp := Sprite3D.new()
		sp.position = base_p
		sp.pixel_size = 0.0066
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.visible = false
		var smat := ShaderMaterial.new()
		smat.shader = shader
		sp.material_override = smat
		add_child(sp)
		_holo_sprites.append(sp)

	# 6. 三大隐藏关微弱异常光球
	var hidden_coords := {
		"penglai": [Vector3(5.32, 0.22, -0.63), CYAN],
		"dazexiang": [Vector3(3.92, 0.22, -0.39), CRIMSON],
		"antarctica": [Vector3(0.0, 0.22, 3.15), CYAN],
	}
	for hid in hidden_coords.keys():
		var orb := _make_ring(hidden_coords[hid][0], 0.16, 0.05, hidden_coords[hid][1], 2.4)
		orb.visible = false
		add_child(orb)
		_hidden_nodes[hid] = orb


func _make_ring(pos: Vector3, outer_r: float, thick: float, col: Color, energy: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = maxf(0.02, outer_r - thick)
	t.outer_radius = outer_r
	t.rings = 28
	t.ring_segments = 12
	m.mesh = t
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = energy
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.position = pos
	return m


func _build_theme() -> Theme:
	var th := Theme.new()
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "SimHei", "Sans-Serif"])
	th.default_font = sf
	th.default_font_size = 15
	return th


func _style(bg: Color, edge: Color, pad: int = 8, radius: int = 6, border_w: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(border_w)
	box.border_color = edge
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 6
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


func _button(parent: Control, title: String, callback: Callable, accent: Color = CYAN) -> Button:
	var button := Button.new()
	button.text = title
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _style(Color(0.06, 0.095, 0.115, 0.9), Color(0.24, 0.34, 0.37, 0.85), 7, 5))
	button.add_theme_stylebox_override("hover", _style(Color(0.11, 0.18, 0.21, 0.96), accent, 7, 5))
	button.add_theme_stylebox_override("pressed", _style(Color(0.04, 0.07, 0.09, 0.96), GOLD, 7, 5))
	button.add_theme_stylebox_override("disabled", _style(Color(0.05, 0.065, 0.075, 0.65), Color(0.16, 0.2, 0.22, 0.5), 7, 5))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _build_ui_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_ui_root = Control.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.theme = _build_theme()
	layer.add_child(_ui_root)

	# 1. 全屏暗黑暗角 + 低民心猩红脉动滤镜
	var vig := ColorRect.new()
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat.shader = preload("res://shaders/vignette.gdshader")
	vig.material = _vignette_mat
	_ui_root.add_child(vig)

	# 2. 地图 2D 投影层（征服金线 + 实时瞄准弧线 + 据点标牌）
	_map_overlay = Control.new()
	_map_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_overlay.draw.connect(_draw_map_overlay)
	_ui_root.add_child(_map_overlay)

	for r in _game_data.regions:
		var id: String = r.id
		var pin := Button.new()
		pin.text = r.name
		pin.size = Vector2(106, 40)
		pin.pivot_offset = pin.size * 0.5
		pin.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pin.add_theme_font_size_override("font_size", 13)
		pin.pressed.connect(_on_pin_clicked.bind(id))
		pin.mouse_entered.connect(_on_pin_hover.bind(id, true))
		pin.mouse_exited.connect(_on_pin_hover.bind(id, false))
		_map_overlay.add_child(pin)
		_pins[id] = pin

		var bar := ProgressBar.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", _style(Color(0.05, 0.08, 0.1, 0.9), Color.TRANSPARENT, 0, 2, 0))
		bar.add_theme_stylebox_override("fill", _style(CYAN, Color.TRANSPARENT, 0, 2, 0))
		bar.position = Vector2(8, 32)
		bar.size = Vector2(90, 4)
		pin.add_child(bar)
		_bars[id] = bar

	# 2b. 地图就地进攻悬浮气泡（点据点立刻贴身弹出，无需拖鼠标去底栏）
	_popover = PanelContainer.new()
	_popover.visible = false
	_popover.add_theme_stylebox_override("panel", _style(Color(0.04, 0.07, 0.09, 0.95), GOLD, 10, 6))
	_map_overlay.add_child(_popover)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 5)
	_popover.add_child(pv)
	_pop_title = _label(pv, "", 15, GOLD)
	_pop_desc = _label(pv, "", 12, MUTED)
	_pop_desc.custom_minimum_size.x = 185
	_pop_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pop_attack = _button(pv, "⚔ 常规进攻", func(): _play_sfx("click"); _result(core.conventional_attack(_selected)), GOLD)

	# 2c. 2 个名臣全息对话气泡（直接浮在名臣立绘旁，不再被战报顶掉）
	for i in range(2):
		var bub := PanelContainer.new()
		bub.visible = false
		bub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bub.add_theme_stylebox_override("panel", _style(Color(0.03, 0.08, 0.11, 0.92), CYAN, 8, 8))
		_ui_root.add_child(bub)
		var bl := _label(bub, "", 13, Color("#dcfbff"))
		bl.custom_minimum_size.x = 190
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bubbles.append(bub)
		_bubble_labels.append(bl)

	# 3. 左上极简悬浮状态胶囊（去后台通栏，把空间还给沙盘）
	var top_pill := PanelContainer.new()
	top_pill.position = Vector2(16, 14)
	top_pill.add_theme_stylebox_override("panel", _style(GLASS_DARK, Color(0.55, 0.44, 0.26, 0.65), 10, 8))
	_ui_root.add_child(top_pill)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	top_pill.add_child(th)
	_label(th, "大秦 · 2076", 17, GOLD)
	_lbl_act = _label(th, "", 14, Color.WHITE)
	var mbox := VBoxContainer.new()
	mbox.add_theme_constant_override("separation", 2)
	th.add_child(mbox)
	_lbl_morale = _label(mbox, "", 13, CYAN)
	_bar_morale = ProgressBar.new()
	_bar_morale.custom_minimum_size = Vector2(108, 6)
	_bar_morale.show_percentage = false
	_bar_morale.add_theme_stylebox_override("background", _style(Color(0.08, 0.11, 0.13, 0.9), Color.TRANSPARENT, 0, 3, 0))
	_bar_morale.add_theme_stylebox_override("fill", _style(CYAN, Color.TRANSPARENT, 0, 3, 0))
	mbox.add_child(_bar_morale)
	_lbl_conquest = _label(th, "", 14, GOLD)
	_lbl_patience = _label(th, "", 14, MUTED)

	# 左上紧凑在场名臣徽章条（不压地图主体）
	_advisors_box = HBoxContainer.new()
	_advisors_box.position = Vector2(16, 66)
	_advisors_box.add_theme_constant_override("separation", 8)
	_ui_root.add_child(_advisors_box)

	# 右上极简功能按钮组
	var util_bar := HBoxContainer.new()
	util_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	util_bar.offset_left = -286; util_bar.offset_top = 14; util_bar.offset_right = -16; util_bar.offset_bottom = 48
	util_bar.alignment = BoxContainer.ALIGNMENT_END
	util_bar.add_theme_constant_override("separation", 6)
	_ui_root.add_child(util_bar)
	_btn_mute = _button(util_bar, "音效", _toggle_mute)
	_button(util_bar, "视角", _toggle_camera)
	_btn_pool = _button(util_bar, "完整池", _toggle_pool)
	_button(util_bar, "重开", func(): _play_sfx("click"); _restart())

	# 4. 右侧悬浮军令卡列（无厚重侧栏背板，卡片独立悬浮）
	var right_col := VBoxContainer.new()
	right_col.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right_col.offset_left = -318; right_col.offset_top = 60; right_col.offset_right = -16; right_col.offset_bottom = -16
	right_col.add_theme_constant_override("separation", 8)
	_ui_root.add_child(right_col)

	var hdr := PanelContainer.new()
	hdr.add_theme_stylebox_override("panel", _style(GLASS_DARK, Color(0.28, 0.42, 0.46, 0.7), 8, 6))
	right_col.add_child(hdr)
	var hv := HBoxContainer.new()
	hdr.add_child(hv)
	_label(hv, "赛博终端", 15, GOLD).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_actions = _label(hv, "", 13, CYAN)

	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 8)
	right_col.add_child(_cards_box)

	_btn_cancel_aim = _button(right_col, "✕ 取消瞄准 (Esc)", func(): _play_sfx("click"); _cancel_aim(), CRIMSON)
	_btn_cancel_aim.visible = false

	var cmd_row := HBoxContainer.new()
	cmd_row.add_theme_constant_override("separation", 6)
	right_col.add_child(cmd_row)
	_btn_refresh = _button(cmd_row, "", func(): _play_sfx("click"); _cancel_aim(); _result(core.refresh_terminal()))
	_btn_refresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_fleet = _button(cmd_row, "", func(): _play_sfx("click"); _cancel_aim(); _result(core.build_fleet()), GOLD)
	_btn_fleet.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var end_btn := _button(right_col, "结束本回合  ⏭", func(): _play_sfx("click"); _cancel_aim(); _result(core.end_turn()), GOLD)
	end_btn.custom_minimum_size.y = 40
	end_btn.add_theme_font_size_override("font_size", 15)
	end_btn.add_theme_color_override("font_color", GOLD)

	# 5. 左下极简战报轻条 + 隐藏关金光按钮
	var bot_box := VBoxContainer.new()
	bot_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bot_box.offset_left = 16; bot_box.offset_top = -84; bot_box.offset_right = 880; bot_box.offset_bottom = -14
	bot_box.add_theme_constant_override("separation", 6)
	_ui_root.add_child(bot_box)

	_hidden_box = HBoxContainer.new()
	_hidden_box.add_theme_constant_override("separation", 8)
	bot_box.add_child(_hidden_box)

	var tick_panel := PanelContainer.new()
	tick_panel.add_theme_stylebox_override("panel", _style(Color(0.03, 0.05, 0.065, 0.78), Color(0.25, 0.35, 0.38, 0.5), 7, 6))
	bot_box.add_child(tick_panel)
	_lbl_ticker = _label(tick_panel, "", 13, Color("#d4e6e8"))

	# 6. 统一暗金模态遮罩与弹窗（突发事件 / 终局 / 满员名臣替换）
	_modal_shade = ColorRect.new()
	_modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_shade.color = Color(0.015, 0.025, 0.035, 0.74)
	_modal_shade.hide()
	_ui_root.add_child(_modal_shade)

	_event_panel = _make_modal(Vector2(500, 290), GOLD)
	var ev_box := VBoxContainer.new()
	ev_box.add_theme_constant_override("separation", 10)
	_event_panel.add_child(ev_box)
	_label(ev_box, "突发急报  /  历史 × 科技", 12, CYAN)
	_event_title = _label(ev_box, "", 20, GOLD)
	_event_desc = _label(ev_box, "", 14, Color("#dbe6e6"))
	_event_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_event_btn_a = _button(ev_box, "", func(): _play_sfx("click"); _event_panel.hide(); core.resolve_event("A"), GOLD)
	_event_btn_b = _button(ev_box, "", func(): _play_sfx("click"); _event_panel.hide(); core.resolve_event("B"), CYAN)

	_ending_panel = _make_modal(Vector2(520, 270), GOLD)
	var end_box := VBoxContainer.new()
	end_box.add_theme_constant_override("separation", 12)
	_ending_panel.add_child(end_box)
	_label(end_box, "大秦终局档案", 12, CYAN)
	_ending_title = _label(end_box, "", 24, GOLD)
	_ending_desc = _label(end_box, "", 15, Color("#e4efef"))
	_ending_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_button(end_box, "再开一局", func(): _play_sfx("click"); _restart(), GOLD)

	_replace_panel = _make_modal(Vector2(490, 270), CYAN)
	var rep_box := VBoxContainer.new()
	rep_box.add_theme_constant_override("separation", 10)
	_replace_panel.add_child(rep_box)
	_label(rep_box, "名臣席位已满（上限 2 位）", 12, CYAN)
	_replace_title = _label(rep_box, "", 19, GOLD)
	_label(rep_box, "选择一位离场名臣：", 13, MUTED)
	_replace_btn_0 = _button(rep_box, "", _confirm_replace.bind(0), GOLD)
	_replace_btn_1 = _button(rep_box, "", _confirm_replace.bind(1), GOLD)
	_button(rep_box, "取消召唤", _cancel_replace, MUTED)


func _make_modal(sz: Vector2, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -sz.x * 0.5
	p.offset_top = -sz.y * 0.5
	p.offset_right = sz.x * 0.5
	p.offset_bottom = sz.y * 0.5
	p.add_theme_stylebox_override("panel", _style(Color(0.04, 0.065, 0.085, 0.96), border, 18, 8, 2))
	p.visible = false
	_ui_root.add_child(p)
	return p


func _apply_camera_targets() -> void:
	if _camera_mode == "sandtable":
		_cam_base_pos = Vector3(1.15, 6.25, 8.65)
		_cam_base_look = Vector3(0.85, -0.35, 0.2)
	else:
		_cam_base_pos = Vector3(1.55, 3.85, 6.45)
		_cam_base_look = Vector3(0.45, 0.45, -1.65)


func _toggle_camera() -> void:
	_play_sfx("click")
	_camera_mode = "closeup" if _camera_mode == "sandtable" else "sandtable"
	_apply_camera_targets()


func _process(delta: float) -> void:
	_anim_time += delta
	# 邪恶冥刻式轻度鼠标视差 + 平滑切镜 + 镜头微震
	var vp := get_viewport().get_visible_rect().size
	if vp.x > 0 and vp.y > 0:
		var m := get_viewport().get_mouse_position()
		_mouse_norm = Vector2((m.x / vp.x) * 2.0 - 1.0, (m.y / vp.y) * 2.0 - 1.0).clamp(Vector2(-1, -1), Vector2(1, 1))
	var parallax := Vector3(_mouse_norm.x * 0.28, -_mouse_norm.y * 0.14, 0.0)
	_cam_cur_pos = _cam_cur_pos.lerp(_cam_base_pos + parallax, minf(1.0, delta * 5.2))
	_cam_cur_look = _cam_cur_look.lerp(_cam_base_look + parallax * 0.22, minf(1.0, delta * 5.2))
	var shake := Vector3.ZERO
	if _shake_strength > 0.004:
		shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _shake_strength
		_shake_strength = maxf(0.0, _shake_strength - delta * 1.4)
	camera.position = _cam_cur_pos + shake
	camera.look_at(_cam_cur_look, Vector3.UP)

	# 火炬柔和摇曳 + 全息名臣上下微浮
	if _torch_left:
		_torch_left.light_energy = 2.1 + 0.35 * sin(_anim_time * 5.2) + 0.18 * cos(_anim_time * 11.7)
	for i in range(_holo_sprites.size()):
		if _holo_sprites[i].visible:
			_holo_sprites[i].position.y = _holo_base_pos[i].y + 0.06 * sin(_anim_time * 2.4 + float(i) * 1.6)
	for i in range(2):
		if _bubble_timers[i] > 0.0:
			_bubble_timers[i] -= delta
			if _bubble_timers[i] <= 0.0:
				_bubbles[i].visible = false

	_update_projected_ui()


func _update_projected_ui() -> void:
	for id in _pins:
		var pin: Button = _pins[id]
		var wpos: Vector3 = _region_pos[id]
		if camera.is_position_behind(wpos):
			pin.visible = false
			continue
		pin.visible = true
		var sp := camera.unproject_position(wpos)
		pin.position = (sp + Vector2(-pin.size.x * 0.5, -pin.size.y - 12.0)).round()

	# 更新就地进攻气泡位置
	if _popover.visible and _region_pos.has(_selected):
		var sp := camera.unproject_position(_region_pos[_selected])
		var vp := get_viewport().get_visible_rect().size
		var px := clampf(sp.x + 26.0, 16.0, vp.x - 340.0 - _popover.size.x)
		var py := clampf(sp.y - 24.0, 72.0, vp.y - 105.0 - _popover.size.y)
		_popover.position = Vector2(px, py).round()

	# 更新名臣全息吐槽气泡位置
	for i in range(2):
		if _bubbles[i].visible:
			var anchor := _holo_base_pos[i] + Vector3(0.0, 0.95, 0.0)
			if not camera.is_position_behind(anchor):
				var bsp := camera.unproject_position(anchor)
				var vp := get_viewport().get_visible_rect().size
				_bubbles[i].position = Vector2(clampf(bsp.x - 105.0, 18.0, vp.x - 540.0), clampf(bsp.y - 48.0, 72.0, vp.y - 160.0)).round()

	_map_overlay.queue_redraw()


func _draw_map_overlay() -> void:
	if _latest.is_empty():
		return
	var cap_sp := camera.unproject_position(XIANYANG_POS)
	for r in _latest.regions:
		var site := camera.unproject_position(_region_pos[r.id])
		var col := _pin_color(r)
		if r.conquered:
			var origin: Vector3 = _region_pos.get(r.prereq, XIANYANG_POS)
			_map_overlay.draw_line(camera.unproject_position(origin), site, Color(GOLD, 0.78), 2.2, true)
			_map_overlay.draw_circle(site, 18.0, Color(GOLD, 0.18))
		var rad := 11.0 if r.id == _hovered_region or r.id == _selected else 7.5
		_map_overlay.draw_circle(site, 4.5, col)
		_map_overlay.draw_arc(site, rad, 0.0, TAU, 24, Color(col, 0.85), 1.6, true)

	# 咸阳金点
	_map_overlay.draw_circle(cap_sp, 5.5, GOLD)
	_map_overlay.draw_arc(cap_sp, 11.0, 0.0, TAU, 24, Color(GOLD, 0.7), 1.5, true)

	# 瞄准指向卡时绘制动态战术弧线与目标准星
	if _pending_cheat_slot >= 0:
		var vp := get_viewport().get_visible_rect().size
		var start_p := Vector2(vp.x - 320.0, vp.y * 0.42)
		var end_p := get_viewport().get_mouse_position()
		var snapped := false
		if _hovered_region != "" and _region_pos.has(_hovered_region):
			end_p = camera.unproject_position(_region_pos[_hovered_region])
			snapped = true
		var mid_p := (start_p + end_p) * 0.5 + Vector2(0.0, -75.0)
		var prev := start_p
		var line_col := GOLD if snapped else CYAN
		for step in range(1, 21):
			var t := float(step) / 20.0
			var q := (1.0 - t) * (1.0 - t) * start_p + 2.0 * (1.0 - t) * t * mid_p + t * t * end_p
			_map_overlay.draw_line(prev, q, Color(line_col, 0.85), 2.5, true)
			prev = q
		var pulse_r := 16.0 + 4.0 * sin(_anim_time * 8.0)
		_map_overlay.draw_arc(end_p, pulse_r, 0.0, TAU, 28, line_col, 2.2, true)


func _unhandled_input(event: InputEvent) -> void:
	if _replace_panel.visible and event.is_action_pressed("ui_cancel"):
		_cancel_replace()
		get_viewport().set_input_as_handled()
		return
	if _modal_shade.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _pending_cheat_slot >= 0:
			_cancel_aim()
			get_viewport().set_input_as_handled()
		elif _popover.visible:
			_selected = ""
			_popover.hide()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for id in _region_pos:
			if camera.unproject_position(_region_pos[id]).distance_to(event.position) <= 28.0:
				_on_pin_clicked(id)
				get_viewport().set_input_as_handled()
				return
		if _popover.visible and not _popover.get_global_rect().has_point(event.position):
			_selected = ""
			_popover.hide()


func _restart() -> void:
	_pending_cheat_slot = -1
	_pending_replace_card_slot = -1
	_selected = ""
	_hovered_region = ""
	_prev_morale = 60
	_prev_patience = 12
	_popover.hide()
	_ending_panel.hide()
	_event_panel.hide()
	_replace_panel.hide()
	_modal_shade.hide()
	for i in range(2):
		_bubbles[i].hide()
		_bubble_timers[i] = 0.0
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
	var old_morale := _prev_morale
	var old_patience := _prev_patience
	var is_first := _latest.is_empty()
	_latest = snap
	_prev_morale = int(snap["morale"])
	_prev_patience = int(snap["patience"])
	_sync_modal_shade()

	# 非开局时，若民心回升或始皇耐心增加，在咸阳爆发金光与飘字反馈
	if not is_first:
		var dm := _prev_morale - old_morale
		var dp := _prev_patience - old_patience
		if dm > 0:
			_spawn_xianyang_pulse(GOLD)
			_spawn_float_text(XIANYANG_POS, "+%d 民心" % dm, SAGE)
		if dp > 0:
			_spawn_xianyang_pulse(CYAN)
			_spawn_float_text(XIANYANG_POS + Vector3(0, 0.35, 0), "+%d 耐心" % dp, GOLD)

	_lbl_act.text = "第 %d 回合 · 第 %d 幕" % [snap["turn"], snap["act"]]
	var low: bool = int(snap["morale"]) < 40
	_lbl_morale.text = "%s民心 %d/%d" % ["⚠ " if low else "", snap["morale"], snap["morale_cap"]]
	_lbl_morale.modulate = CRIMSON if low else CYAN
	_bar_morale.max_value = int(snap["morale_cap"])
	_bar_morale.value = int(snap["morale"])
	_bar_morale.add_theme_stylebox_override("fill", _style(CRIMSON if low else CYAN, Color.TRANSPARENT, 0, 3, 0))
	_lbl_conquest.text = "统一 %d/6" % snap["conquered_count"]
	_lbl_patience.text = "耐心 %d" % snap["patience"]
	_lbl_actions.text = "行动 %s  进攻 %d/1" % ["●".repeat(snap["actions_left"]) + "○".repeat(2 - snap["actions_left"]), snap["attack_left"]]

	# 低民心警报滤镜 + 火炬变红
	_vignette_mat.set_shader_parameter("danger_intensity", 1.0 if low else 0.0)
	_torch_left.light_color = Color("#ff3b3b") if low else Color("#ffaa44")

	# 更新 3D 板块信标与地图鎏金染色
	var occupied := PackedFloat32Array()
	for r in snap["regions"]:
		occupied.append(1.0 if r.conquered else 0.0)
		var m: MeshInstance3D = _region_meshes.get(r["id"])
		if m and m.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = m.material_override
			var col := GOLD if r["conquered"] else (CYAN if (_pending_cheat_slot >= 0 or core.can_attack_region(r["id"])) else Color("#576669"))
			mat.albedo_color = col
			mat.emission = col
			mat.emission_energy_multiplier = 2.0 if r["conquered"] else (1.8 if _pending_cheat_slot >= 0 else 0.9)
	occupied.append(0.0)
	_map_material.set_shader_parameter("occupied", occupied)

	# 更新 3D 全息名臣 + 投影环 + 左上紧凑槽位
	var advs: Array = snap["advisors"]
	for i in range(2):
		var sp := _holo_sprites[i]
		var ring := _holo_rings[i]
		if i < advs.size():
			var p_path: String = advs[i].get("portrait", "")
			if p_path != "" and ResourceLoader.exists(p_path):
				var tex: Texture2D = load(p_path)
				sp.texture = tex
				(sp.material_override as ShaderMaterial).set_shader_parameter("albedo_tex", tex)
			sp.visible = true
			ring.visible = true
		else:
			sp.visible = false
			ring.visible = false
	_refresh_advisor_chips(advs)

	# 隐藏关按钮与 3D 异常光环
	for ch in _hidden_box.get_children():
		ch.queue_free()
	var hvis: Dictionary = snap["hidden_visible"]
	for hid in hvis.keys():
		if _hidden_nodes.has(hid):
			_hidden_nodes[hid].visible = bool(hvis[hid])
		if bool(hvis[hid]):
			var hname := str({"penglai":"蓬莱仙岛", "dazexiang":"大泽乡暗流", "antarctica":"南极时间舱"}.get(hid, hid))
			var hb := _button(_hidden_box, "✦ 探索 · " + hname, func(): _play_sfx("click"); _cancel_aim(); _result(core.trigger_hidden(hid)), GOLD)
			hb.add_theme_color_override("font_color", GOLD)

	if bool(snap.get("free_hook_available", false)):
		_lbl_ticker.text = "★ 首回合高光：右侧首次召唤【名臣】或部署【无人机蜂群】免民心；点击地图据点可直接出兵！"
	elif _lbl_ticker.text == "":
		_lbl_ticker.text = "点击任意绿色/青色高亮据点弹出进攻指令，双击可快速常规进攻。"

	_refresh_commands()


func _refresh_advisor_chips(advs: Array) -> void:
	for ch in _advisors_box.get_children():
		_advisors_box.remove_child(ch)
		ch.queue_free()
	for i in range(2):
		var chip := PanelContainer.new()
		var has_a := i < advs.size()
		chip.add_theme_stylebox_override("panel", _style(Color(0.05, 0.085, 0.11, 0.84) if has_a else Color(0.04, 0.06, 0.075, 0.55), GOLD if has_a else Color(0.22, 0.3, 0.32, 0.5), 5, 6))
		_advisors_box.add_child(chip)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		chip.add_child(row)
		if has_a:
			var adv: Dictionary = advs[i]
			if ResourceLoader.exists(adv.get("portrait", "")):
				var tr := TextureRect.new()
				tr.texture = load(adv["portrait"])
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.custom_minimum_size = Vector2(26, 26)
				row.add_child(tr)
			_label(row, adv["name"], 13, GOLD)
			chip.tooltip_text = "【%s】%s" % [adv["name"], adv["skill"]]
		else:
			_label(row, "席位 %d · 空" % (i + 1), 12, Color("#627578"))
			chip.tooltip_text = "最多同时在场 2 位历史名臣"


func _refresh_commands() -> void:
	for child in _cards_box.get_children():
		_cards_box.remove_child(child)
		child.queue_free()
	for i in range(_latest.terminal_cards.size()):
		_add_card(i)
	_btn_cancel_aim.visible = _pending_cheat_slot >= 0
	_btn_refresh.text = "刷新 %d/3 (−%d)" % [_latest.refreshes_left, core.get_refresh_cost()]
	_btn_refresh.disabled = _latest.refreshes_left <= 0 or _latest.overheat_no_refresh
	_btn_fleet.text = "航线已通" if _latest.sea_unlocked else "造楼船 (−%d)" % core.get_fleet_cost()
	_btn_fleet.disabled = _latest.sea_unlocked or _latest.actions_left <= 0
	_refresh_pins_and_popover()


func _add_card(slot: int) -> void:
	var card: Dictionary = _latest.terminal_cards[slot]
	var data: Dictionary = card.data
	var advisor: bool = card.kind == "advisor"
	var kind: String = "名臣" if advisor else {"military":"军事", "livelihood":"民生", "blacktech":"奇术"}[data.category]
	var tint: Color = {"军事":CYAN, "民生":SAGE, "奇术":VIOLET, "名臣":GOLD}[kind]
	var is_free_hook: bool = (not card.bought) and bool(_latest.get("free_hook_available", false)) and (advisor or data.id == "drone")
	var delta := -core.get_effective_advisor_cost(data) if advisor else core.get_effective_cheat_delta(data)
	if delta < 0 and _latest.cyber_burn_turns > 0:
		delta = 0
	var badge_txt := "★ 免费" if is_free_hook else ("已部署" if card.bought else ("%+d 民心" % delta if delta != 0 else "免民心"))

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(300, 102)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.disabled = card.bought or _latest.actions_left <= 0 or (data.id == "education" and _latest.attack_left <= 0)
	var active := slot == _pending_cheat_slot
	var base_bg := Color(0.09, 0.19, 0.22, 0.95) if active else (Color(0.08, 0.12, 0.14, 0.92) if is_free_hook else Color(0.055, 0.088, 0.108, 0.88))
	var edge := GOLD if is_free_hook else (tint if active else Color(0.24, 0.34, 0.37, 0.85))
	var normal_box := _style(base_bg, edge, 0, 7, 1)
	normal_box.border_width_left = 4
	normal_box.border_color = GOLD if is_free_hook else tint
	var hover_box := _style(Color(0.11, 0.18, 0.21, 0.97), GOLD if is_free_hook else tint, 0, 7, 2)
	hover_box.border_width_left = 5
	btn.add_theme_stylebox_override("normal", normal_box)
	btn.add_theme_stylebox_override("hover", hover_box)
	btn.add_theme_stylebox_override("pressed", hover_box)
	btn.add_theme_stylebox_override("disabled", _style(Color(0.04, 0.06, 0.07, 0.55), Color(0.16, 0.2, 0.22, 0.45), 0, 7, 1))
	btn.pressed.connect(_use_card.bind(slot))
	_cards_box.add_child(btn)

	# 悬停弹性微抬反馈
	btn.mouse_entered.connect(func():
		if not btn.disabled:
			btn.pivot_offset = btn.size * 0.5
			var tw := btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2(1.025, 1.025), 0.12)
	)
	btn.mouse_exited.connect(func():
		var tw := btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.12)
	)

	var body := VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 13; body.offset_top = 7; body.offset_right = -10; body.offset_bottom = -7
	body.add_theme_constant_override("separation", 3)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(body)

	var top_r := HBoxContainer.new()
	top_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(top_r)
	var k_lbl := _label(top_r, "%s · %s" % [kind, "瞄准中" if active else ("入列" if advisor else ("点选目标" if data.needs_target else "即刻生效"))], 12, tint)
	k_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b_col := GOLD if is_free_hook else (SAGE if delta > 0 else (CRIMSON if delta < 0 else MUTED))
	var badge := _label(top_r, badge_txt, 13, b_col)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 7)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(title_row)
	if advisor and ResourceLoader.exists(data.portrait):
		var pr := TextureRect.new()
		pr.texture = load(data.portrait)
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pr.custom_minimum_size = Vector2(26, 26)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_row.add_child(pr)
	_label(title_row, data.name, 17, Color.WHITE).mouse_filter = Control.MOUSE_FILTER_IGNORE

	var desc: String = data.skill if advisor else data.desc
	if not advisor and data.needs_target:
		var punch := "直接攻克" if data.id == "nuke_seal" or (data.id == "drone" and core.has_advisor("huoqubing")) else "%d 战力打击" % _card_damage(data, 0)
		desc = "任选未占领板块 · " + punch + ("，开通渡海" if data.id == "ironclad" else "")
	var dl := _label(body, desc, 12, MUTED)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if btn.disabled:
		body.modulate = Color(0.58, 0.62, 0.64, 0.8)


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
		_popover.hide()
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
				_spawn_xianyang_pulse(CYAN)
			_result(res)
	else:
		var res := core.buy_cheat(slot)
		if res.get("ok", false):
			_play_sfx("summon")
			if card.data.id == "cyber_burn":
				_spawn_xianyang_pulse(VIOLET)
				_spawn_float_text(XIANYANG_POS, "民心锁死 2 回合", VIOLET)
			elif card.data.id == "ak47" or card.data.id == "cement_road":
				_spawn_xianyang_pulse(GOLD)
				_spawn_float_text(XIANYANG_POS, "常规秦军强化！", GOLD)
		_result(res)


func _open_replace_dialog(card_slot: int, incoming: Dictionary) -> void:
	_pending_replace_card_slot = card_slot
	_replace_title.text = "召唤【%s】入列" % incoming["name"]
	var a0: Dictionary = _latest.advisors[0]
	var a1: Dictionary = _latest.advisors[1]
	_replace_btn_0.text = "替换 1 号席：%s（%s）" % [a0["name"], str(a0["skill"]).substr(0, 18)]
	_replace_btn_1.text = "替换 2 号席：%s（%s）" % [a1["name"], str(a1["skill"]).substr(0, 18)]
	_replace_panel.show()
	_sync_modal_shade()


func _confirm_replace(replace_idx: int) -> void:
	_play_sfx("click")
	var slot := _pending_replace_card_slot
	_pending_replace_card_slot = -1
	_replace_panel.hide()
	_sync_modal_shade()
	if slot >= 0:
		var res := core.summon_advisor(slot, replace_idx)
		if res.get("ok", false):
			_play_sfx("summon")
			_spawn_xianyang_pulse(CYAN)
		_result(res)


func _cancel_replace() -> void:
	_play_sfx("click")
	_pending_replace_card_slot = -1
	_replace_panel.hide()
	_sync_modal_shade()


func _cancel_aim() -> void:
	if _pending_cheat_slot != -1:
		_pending_cheat_slot = -1
		_refresh_commands()


func _on_pin_hover(id: String, entered: bool) -> void:
	_hovered_region = id if entered else ("" if _hovered_region == id else _hovered_region)
	var pin: Button = _pins[id]
	var tw := pin.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(pin, "scale", Vector2(1.08, 1.08) if entered else Vector2.ONE, 0.1)


func _on_pin_clicked(id: String) -> void:
	if _modal_shade.visible:
		return
	_play_sfx("click")
	if _pending_cheat_slot >= 0:
		var slot := _pending_cheat_slot
		_pending_cheat_slot = -1
		var res := core.buy_cheat(slot, id)
		if not res.get("ok", false):
			_pending_cheat_slot = slot
			_result(res)
		_refresh_commands()
		return

	# 再次点击已选中的可进攻板块 → 直接常规进攻（省掉二次找按钮）
	if _selected == id and _popover.visible and core.can_attack_region(id) and _latest.attack_left > 0 and not _latest.education_turn:
		_result(core.conventional_attack(id))
		return

	_selected = id
	_refresh_pins_and_popover()


func _pin_color(r: Dictionary) -> Color:
	if r.conquered:
		return GOLD
	if _pending_cheat_slot >= 0 or core.can_attack_region(r.id):
		return CYAN
	return MUTED


func _refresh_pins_and_popover() -> void:
	_popover.hide()
	for r in _latest.regions:
		var pin: Button = _pins[r.id]
		var bar: ProgressBar = _bars[r.id]
		var tint := _pin_color(r)
		pin.text = ("◆ " if r.conquered else "") + str(r.name)
		pin.add_theme_color_override("font_color", tint)
		var sel: bool = (r.id == _selected)
		pin.add_theme_stylebox_override("normal", _style(Color(0.09, 0.16, 0.19, 0.94) if sel else Color(0.04, 0.075, 0.095, 0.88), tint if sel or r.conquered else tint.darkened(0.45), 2, 5, 2 if sel else 1))
		pin.add_theme_stylebox_override("hover", _style(Color(0.11, 0.2, 0.24, 0.97), GOLD if r.conquered else CYAN, 2, 5, 2))
		bar.max_value = r.max_hp
		bar.value = r.hp
		bar.add_theme_stylebox_override("fill", _style(GOLD if r.conquered else CYAN, Color.TRANSPARENT, 0, 2, 0))
		pin.tooltip_text = "%s · 守军 %d/%d" % [r.coverage, r.hp, r.max_hp]
		if _pending_cheat_slot >= 0 and not r.conquered:
			var dmg := _card_damage(_latest.terminal_cards[_pending_cheat_slot].data, int(r.hp))
			pin.tooltip_text += " → 剩余 %d" % maxi(0, int(r.hp) - dmg)

		if r.id == _selected and _pending_cheat_slot < 0:
			_popover.show()
			_pop_title.text = "%s  ·  %s" % [r.name, "已归玄黑" if r.conquered else "守军 %d/%d" % [r.hp, r.max_hp]]
			if r.conquered:
				_pop_desc.text = r.reward
				_pop_attack.hide()
			else:
				var ready := core.can_attack_region(r.id)
				var eff := 1.0 if r.id == "south_asia" and _latest.penicillin_turn else float(r.efficiency)
				var dmg := floori(eff * _latest.conventional_power)
				_pop_attack.show()
				_pop_attack.text = "⚔ 常规进攻 (−%d 战力)" % dmg
				_pop_attack.disabled = not ready or _latest.attack_left <= 0 or _latest.education_turn
				if not ready:
					_pop_desc.text = "需先开通渡海航线（造楼船或跨海铁甲舰）。" if r.requires_sea else "需先攻克前置板块。"
				elif _latest.education_turn:
					_pop_desc.text = "本回合已推行义务教育，无法常规进攻。"
				elif _latest.attack_left <= 0:
					_pop_desc.text = "本回合常规进攻已用完，可用军事外挂。"
				else:
					_pop_desc.text = "%s（再次点击据点也可直接出兵）" % r.reward


func _spawn_strike_fx(region_id: String, conquered: bool) -> void:
	if not _region_pos.has(region_id):
		return
	var target: Vector3 = _region_pos[region_id]
	var fx_col := GOLD if conquered else CYAN
	_shake_strength = 0.28 if conquered else 0.13

	# 1. 从咸阳飞向目标板块的弧形能量弹道
	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14 if conquered else 0.1
	sm.height = sm.radius * 2.0
	orb.mesh = sm
	var omat := StandardMaterial3D.new()
	omat.albedo_color = fx_col
	omat.emission_enabled = true
	omat.emission = fx_col
	omat.emission_energy_multiplier = 4.0
	orb.material_override = omat
	orb.position = XIANYANG_POS
	add_child(orb)

	var mid := (XIANYANG_POS + target) * 0.5 + Vector3(0.0, 2.2, 0.0)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		orb.position = (1.0 - t) * (1.0 - t) * XIANYANG_POS + 2.0 * (1.0 - t) * t * mid + t * t * target
	, 0.0, 1.0, 0.24)
	tw.tween_callback(func():
		orb.queue_free()
		_spawn_impact_burst(target, fx_col, conquered)
	)


func _spawn_impact_burst(target: Vector3, fx_col: Color, big: bool) -> void:
	var ring := _make_ring(target + Vector3(0, 0.05, 0), 0.25, 0.06, fx_col, 3.6)
	add_child(ring)
	var rmat: StandardMaterial3D = ring.material_override
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var end_s := 4.8 if big else 3.0
	tw.tween_property(ring, "scale", Vector3(end_s, 1.0, end_s), 0.48)
	tw.parallel().tween_property(rmat, "albedo_color:a", 0.0, 0.48)
	tw.parallel().tween_property(rmat, "emission_energy_multiplier", 0.0, 0.48)
	tw.finished.connect(ring.queue_free)


func _spawn_xianyang_pulse(col: Color) -> void:
	_spawn_impact_burst(XIANYANG_POS, col, true)


func _spawn_float_text(world_pos: Vector3, text: String, col: Color) -> void:
	if camera.is_position_behind(world_pos):
		return
	var sp := camera.unproject_position(world_pos)
	var lbl := _label(_map_overlay, text, 22, col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.add_theme_color_override("font_outline_color", Color("#05090d"))
	lbl.position = sp + Vector2(-42.0, -34.0)
	var tw := lbl.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", lbl.position.y - 38.0, 0.55)
	tw.tween_interval(0.35)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3)
	tw.tween_callback(lbl.queue_free)


func _result(res: Dictionary) -> void:
	if not res.get("ok", false):
		_lbl_ticker.text = "⚠ " + str(res.get("error", "操作未完成"))


func _on_strike_performed(region_id: String, damage: int, source: String, conquered: bool) -> void:
	_play_sfx("conquer" if conquered else "strike")
	_spawn_strike_fx(region_id, conquered)
	var region: Dictionary = _latest.regions.filter(func(r): return r.id == region_id)[0]
	var loss := mini(damage, int(region.hp))
	_spawn_float_text(_region_pos[region_id], "−%d%s" % [loss, " ★攻克" if conquered else ""], GOLD if conquered else CYAN)
	_lbl_ticker.text = "%s 命中【%s】−%d · %s" % [source, region.name, loss, "已染玄黑！" if conquered else "守军剩余 %d" % (int(region.hp) - loss)]
	if conquered:
		_popover.hide()


func _on_advisor_spoke(aid: String, advisor_name: String, line: String) -> void:
	# 优先在对应名臣的全息立绘旁弹出专属对白气泡
	var slot_idx := 0
	var advs: Array = _latest.get("advisors", [])
	for i in range(advs.size()):
		if advs[i].get("id", "") == aid:
			slot_idx = i
			break
	if slot_idx < _bubbles.size():
		_bubble_labels[slot_idx].text = "【%s】「%s」" % [advisor_name, line]
		_bubbles[slot_idx].visible = true
		_bubble_timers[slot_idx] = 4.5
	_lbl_ticker.text = "【%s】「%s」" % [advisor_name, line]


func _on_hidden_triggered(hidden_id: String, reward_text: String) -> void:
	_play_sfx("summon")
	_spawn_xianyang_pulse(GOLD)
	_lbl_ticker.text = "✦ 隐藏关【%s】：%s" % [hidden_id, reward_text]


func _on_event_triggered(ev: Dictionary) -> void:
	_play_sfx("event")
	_popover.hide()
	_event_title.text = ev["title"]
	_event_desc.text = ev["desc"]
	_event_btn_a.text = "A. %s" % ev["option_a"]["label"]
	_event_btn_b.text = "B. %s" % ev["option_b"]["label"]
	_event_panel.show()
	_sync_modal_shade()


func _on_game_ended(code: String, data: Dictionary) -> void:
	_play_sfx("victory" if code.begins_with("win_") else "defeat")
	_popover.hide()
	_ending_title.text = "%s" % data.get("title", "终局")
	_ending_desc.text = "%s\n（结局代码：%s）" % [data.get("prompt", ""), code]
	_ending_panel.show()
	_sync_modal_shade()
