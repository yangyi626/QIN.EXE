extends Control
## 《大秦：2076》2.5D 咸阳宫暗黑立体桌面与拟物手牌表现层（v2.6 · 完整参赛版）
## 严格遵循逻辑与表现分离：仅调用 GameCore 公开方法并订阅信号，不反向篡改核心状态。

var core := GameCore.new()
var _game_data: Dictionary = {}
var _lines_data: Dictionary = {}
var _mvp_only: bool = false

# 调色板（玄黑 / 暗青铜 / 火把鎏金 / 赛博青 / 警报猩红）
const GOLD := Color("#f2c272")
const CYAN := Color("#4df3ff")
const SAGE := Color("#8ee3a1")
const VIOLET := Color("#d4a8ff")
const CRIMSON := Color("#ff4242")
const MUTED := Color("#a8b8ba")

# 精准对齐 bg_xianyang_desk.jpg 的归一化舞台坐标（随视差与分辨率自动锁死）
const UV_CAULDRON := Vector2(0.102, 0.455)
const UV_TORCH_L := Vector2(0.118, 0.165)
const UV_TORCH_R := Vector2(0.878, 0.165)
const UV_EMPEROR := Vector2(0.500, 0.275)
const UV_CRT := Vector2(0.865, 0.545)
const UV_XIANYANG := Vector2(0.655, 0.618)
const UV_ADVISORS: Array[Vector2] = [Vector2(0.305, 0.345), Vector2(0.695, 0.345)]
const UV_REGIONS := {
	"steppe": Vector2(0.618, 0.566),
	"west": Vector2(0.576, 0.598),
	"south_asia": Vector2(0.694, 0.678),
	"west_asia": Vector2(0.514, 0.646),
	"europe": Vector2(0.506, 0.575),
	"americas": Vector2(0.342, 0.656),
}
const UV_HIDDEN := {
	"penglai": Vector2(0.726, 0.612),
	"dazexiang": Vector2(0.662, 0.640),
	"antarctica": Vector2(0.500, 0.778),
}
const HIDDEN_HINTS := {
	"penglai": "✦ 东海异常乱码 · 蓬莱仙岛(1行动)",
	"dazexiang": "✦ 大泽乡暗红火星 · 需名臣安抚(1行动)",
	"antarctica": "✦ 南极金属反光 · 时间舱(1刷新)",
}
const ACT_TITLES := {
	1: ["第一幕 · 始皇初望", "咸阳终端初启，六洲烽火未熄"],
	2: ["第二幕 · 铁骑西征", "跨时空军工入列，民心与霸业拉扯"],
	3: ["第三幕 · 寰宇决战", "始皇耐心告急，终局近在眼前"],
}

# 贴图缓存
var _tex_bg: Texture2D
var _tex_card: Texture2D
var _tex_panel: Texture2D
var _tex_end_win: Texture2D
var _tex_end_tyrant: Texture2D
var _tex_end_lose: Texture2D
var _category_icons: Dictionary = {}

# 舞台与动画状态
var _stage: Control
var _bg_rect: TextureRect
var _stage_fx: Control
var _flash_rect: ColorRect
var _vignette_mat := ShaderMaterial.new()
var _holo_rects: Array[TextureRect] = []
var _holo_names: Array[Label] = []
var _bubbles: Array[PanelContainer] = []
var _bubble_labels: Array[Label] = []
var _bubble_timers: Array[float] = [0.0, 0.0]

var _anim_time: float = 0.0
var _parallax_cur := Vector2.ZERO
var _shake_strength: float = 0.0
var _projectiles: Array[Dictionary] = []
var _pulses: Array[Dictionary] = []
var _embers: Array[Dictionary] = []

# 音频系统
var _audio_muted: bool = false
var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _hover_player: AudioStreamPlayer
var _uprising_player: AudioStreamPlayer
var _bgm_ambient_stream: AudioStream
var _bgm_act3_stream: AudioStream
var _sfx_bank: Dictionary = {}

# 游戏交互状态
var _latest: Dictionary = {}
var _prev_morale: int = 60
var _prev_patience: int = 12
var _prev_act: int = 0
var _last_cards_sig: String = ""
var _hidden_triggered_count: int = 0
var _selected: String = ""
var _hovered_region: String = ""
var _hovered_hidden: String = ""
var _pending_cheat_slot: int = -1
var _pending_replace_card_slot: int = -1

# UI 节点
var _hand_layer: Control
var _card_nodes: Array[Control] = []
var _card_base_pos: Array[Vector2] = []
var _card_base_rot: Array[float] = [-3.0, 0.0, 3.0]
var _popover: PanelContainer
var _pop_title: Label
var _pop_desc: Label
var _pop_attack: Button
var _crt_status: Label
var _lbl_act: Label
var _lbl_morale: Label
var _bar_morale: ProgressBar
var _lbl_conquest: Label
var _lbl_patience: Label
var _buffs_box: HBoxContainer
var _lbl_ticker: Label
var _btn_refresh: Button
var _btn_fleet: Button
var _btn_pool: Button
var _btn_mute: Button
var _btn_cancel_aim: Button
var _hidden_box: HBoxContainer
var _act_banner: PanelContainer
var _act_banner_title: Label
var _act_banner_sub: Label
var _title_curtain: Control
var _rules_panel: PanelContainer
var _log_panel: PanelContainer
var _log_text: Label
var _modal_shade: ColorRect
var _event_panel: PanelContainer
var _event_title: Label
var _event_desc: Label
var _event_btn_a: Button
var _event_btn_b: Button
var _ending_panel: PanelContainer
var _ending_cg: TextureRect
var _ending_grade: Label
var _ending_title: Label
var _ending_desc: Label
var _ending_stats: Label
var _replace_panel: PanelContainer
var _replace_title: Label
var _replace_btn_0: Button
var _replace_btn_1: Button


func _ready() -> void:
	theme = _build_theme()
	_game_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))
	_lines_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/lines.json"))
	_tex_bg = load("res://assets/textures/bg_xianyang_desk.jpg")
	_tex_card = load("res://assets/textures/card_frame_obsidian.jpg")
	_tex_panel = load("res://assets/textures/panel_frame_bronze.jpg")
	_tex_end_win = load("res://assets/textures/ending_victory.jpg")
	_tex_end_tyrant = load("res://assets/textures/ending_tyrant.jpg")
	_tex_end_lose = load("res://assets/textures/ending_defeat.jpg")
	_category_icons = {
		"military": load("res://assets/icons/icon_military.jpg"),
		"livelihood": load("res://assets/icons/icon_livelihood.jpg"),
		"blacktech": load("res://assets/icons/icon_blacktech.jpg"),
	}

	_init_embers()
	_setup_audio()
	_build_stage_and_ui()

	core.state_changed.connect(_on_state_changed)
	core.strike_performed.connect(_on_strike_performed)
	core.event_triggered.connect(_on_event_triggered)
	core.advisor_spoke.connect(_on_advisor_spoke)
	core.hidden_triggered.connect(_on_hidden_triggered)
	core.game_ended.connect(_on_game_ended)

	get_viewport().size_changed.connect(_layout_dynamic_elements)
	_restart(false)


func _build_theme() -> Theme:
	var th := Theme.new()
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "SimHei", "Sans-Serif"])
	th.default_font = sf
	th.default_font_size = 15
	return th


func _init_embers() -> void:
	_embers.clear()
	var sources: Array[Vector2] = [UV_CAULDRON, UV_CAULDRON, UV_TORCH_L, UV_TORCH_R]
	for i in range(28):
		var src: Vector2 = sources[i % sources.size()]
		_embers.append({
			"src": src,
			"life": randf(),
			"speed": randf_range(0.16, 0.34),
			"drift": randf_range(-0.025, 0.025),
			"phase": randf() * TAU,
			"size": randf_range(1.4, 3.0),
		})


func _setup_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = -14.0
	add_child(_bgm_player)
	if ResourceLoader.exists("res://assets/audio/bgm_ambient.wav"):
		_bgm_ambient_stream = load("res://assets/audio/bgm_ambient.wav")
	if ResourceLoader.exists("res://assets/audio/bgm_act3_drums.wav"):
		_bgm_act3_stream = load("res://assets/audio/bgm_act3_drums.wav")
	_bgm_player.stream = _bgm_ambient_stream
	_bgm_player.finished.connect(func():
		if not _audio_muted and _bgm_player.stream != null:
			_bgm_player.play()
	)
	if _bgm_player.stream != null:
		_bgm_player.play()

	_uprising_player = AudioStreamPlayer.new()
	_uprising_player.volume_db = -30.0
	add_child(_uprising_player)
	if ResourceLoader.exists("res://assets/audio/sfx_uprising_loop.wav"):
		_uprising_player.stream = load("res://assets/audio/sfx_uprising_loop.wav")
		_uprising_player.finished.connect(func():
			if not _audio_muted and _prev_morale < 40 and _uprising_player.stream != null:
				_uprising_player.play()
		)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.volume_db = -6.0
	add_child(_sfx_player)

	_hover_player = AudioStreamPlayer.new()
	_hover_player.volume_db = -12.0
	add_child(_hover_player)

	var names := {
		"click": "res://assets/audio/sfx_click.wav",
		"hover": "res://assets/audio/sfx_card_hover.wav",
		"chime": "res://assets/audio/sfx_turn_chime.wav",
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
	if key == "hover":
		_hover_player.stream = _sfx_bank[key]
		_hover_player.play()
	else:
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
		_hover_player.stop()
		if _uprising_player:
			_uprising_player.stop()
	else:
		if _bgm_player.stream != null:
			_bgm_player.play()
		if _uprising_player and _uprising_player.stream != null and _prev_morale < 40:
			_uprising_player.play()


func _plaque_style(pad_x: int = 18, pad_y: int = 14) -> StyleBoxTexture:
	var st := StyleBoxTexture.new()
	st.texture = _tex_panel
	st.texture_margin_left = 48
	st.texture_margin_right = 48
	st.texture_margin_top = 36
	st.texture_margin_bottom = 36
	st.content_margin_left = pad_x
	st.content_margin_right = pad_x
	st.content_margin_top = pad_y
	st.content_margin_bottom = pad_y
	return st


func _flat_style(bg: Color, edge: Color, pad: int = 7, rad: int = 5) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = edge
	b.set_border_width_all(1)
	b.set_corner_radius_all(rad)
	for s in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		b.set_content_margin(s, pad)
	return b


func _label(parent: Control, text: String, sz: int, col: Color, shadow: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.modulate = col
	if shadow:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, cb: Callable, accent: Color = GOLD) -> Button:
	var b := Button.new()
	b.text = text
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _flat_style(Color(0.055, 0.068, 0.08, 0.88), Color(0.36, 0.3, 0.2, 0.85), 7, 5))
	b.add_theme_stylebox_override("hover", _flat_style(Color(0.11, 0.14, 0.16, 0.96), accent, 7, 5))
	b.add_theme_stylebox_override("pressed", _flat_style(Color(0.04, 0.05, 0.06, 0.96), GOLD, 7, 5))
	b.add_theme_stylebox_override("disabled", _flat_style(Color(0.04, 0.05, 0.06, 0.55), Color(0.18, 0.18, 0.19, 0.45), 7, 5))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _screen_flash(col: Color, alpha: float = 0.45, dur: float = 0.42) -> void:
	if _flash_rect == null:
		return
	_flash_rect.color = Color(col.r, col.g, col.b, alpha)
	_flash_rect.visible = true
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_flash_rect, "color:a", 0.0, dur)
	tw.tween_callback(_flash_rect.hide)


func _build_stage_and_ui() -> void:
	# 1. 2.5D 咸阳宫第一人称精绘桌景舞台
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_bg_rect = TextureRect.new()
	_bg_rect.texture = _tex_bg
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_bg_rect)

	# 2. 两位名臣 2D 羽化全息投影（支持鼠标悬停查看常驻被动技能）
	var holo_shader: Shader = load("res://shaders/hologram_2d.gdshader")
	for i in range(2):
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = Vector2(186, 186)
		tr.visible = false
		tr.mouse_filter = Control.MOUSE_FILTER_STOP
		tr.mouse_default_cursor_shape = Control.CURSOR_HELP
		var sm := ShaderMaterial.new()
		sm.shader = holo_shader
		tr.material = sm
		_stage.add_child(tr)
		_holo_rects.append(tr)

		var nl := _label(_stage, "", 13, CYAN)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.visible = false
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_holo_names.append(nl)

	# 3. 舞台自定义绘制层（始皇压迫光晕、烛火火星、鼎火脉动、沙盘印记点与血条、弹道、瞄准弧线）
	_stage_fx = Control.new()
	_stage_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_fx.draw.connect(_draw_stage_fx)
	_stage.add_child(_stage_fx)

	# 3b. 右侧复古赛博 CRT 屏幕内荧光读数
	_crt_status = _label(_stage, "", 12, Color("#88faff"))
	_crt_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crt_status.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 4. 电影感暗角 + 低民心猩红脉动滤镜 + 瞬时高光闪屏层
	var vig := ColorRect.new()
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat.shader = preload("res://shaders/vignette.gdshader")
	vig.material = _vignette_mat
	add_child(vig)

	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.visible = false
	add_child(_flash_rect)

	# 5. 名臣全息对白气泡
	for i in range(2):
		var bub := PanelContainer.new()
		bub.visible = false
		bub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bub.add_theme_stylebox_override("panel", _flat_style(Color(0.025, 0.065, 0.085, 0.92), CYAN, 9, 8))
		add_child(bub)
		var bl := _label(bub, "", 13, Color("#e0fdff"))
		bl.custom_minimum_size.x = 200
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bubbles.append(bub)
		_bubble_labels.append(bl)

	# 6. 地图就地战术情报牌（青铜雕花贴图）
	_popover = PanelContainer.new()
	_popover.visible = false
	_popover.add_theme_stylebox_override("panel", _plaque_style(16, 14))
	add_child(_popover)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	_popover.add_child(pv)
	_pop_title = _label(pv, "", 15, GOLD)
	_pop_desc = _label(pv, "", 12, MUTED)
	_pop_desc.custom_minimum_size.x = 200
	_pop_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pop_attack = _button(pv, "⚔ 常规进攻", func(): _play_sfx("click"); _result(core.conventional_attack(_selected)), GOLD)

	# 7. 底部中央扇形实体手牌层
	_hand_layer = Control.new()
	_hand_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_layer)

	# 8. 右下角 CRT 终端指令按键组
	var crt_cmds := VBoxContainer.new()
	crt_cmds.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	crt_cmds.offset_left = -224; crt_cmds.offset_top = -170; crt_cmds.offset_right = -18; crt_cmds.offset_bottom = -16
	crt_cmds.add_theme_constant_override("separation", 7)
	add_child(crt_cmds)

	_btn_cancel_aim = _button(crt_cmds, "✕ 取消瞄准 (Esc)", func(): _play_sfx("click"); _cancel_aim(), CRIMSON)
	_btn_cancel_aim.visible = false
	_btn_refresh = _button(crt_cmds, "", func(): _play_sfx("click"); _cancel_aim(); _result(core.refresh_terminal()), CYAN)
	_btn_fleet = _button(crt_cmds, "", func(): _play_sfx("click"); _cancel_aim(); _result(core.build_fleet()), GOLD)
	var end_btn := _button(crt_cmds, "结束本回合  ⏭", func(): _play_sfx("chime"); _cancel_aim(); _result(core.end_turn()), GOLD)
	end_btn.custom_minimum_size.y = 38
	end_btn.add_theme_color_override("font_color", GOLD)

	# 9. 左上极简青铜状态牌 + 实时 Buff 徽章条 + 右上工具胶囊
	var top_plaque := PanelContainer.new()
	top_plaque.position = Vector2(14, 12)
	top_plaque.add_theme_stylebox_override("panel", _flat_style(Color(0.035, 0.045, 0.055, 0.82), Color(0.55, 0.43, 0.24, 0.65), 9, 7))
	add_child(top_plaque)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	top_plaque.add_child(th)
	_label(th, "大秦 · 2076", 16, GOLD)
	_lbl_act = _label(th, "", 13, Color.WHITE)
	var mbox := VBoxContainer.new()
	mbox.add_theme_constant_override("separation", 2)
	th.add_child(mbox)
	_lbl_morale = _label(mbox, "", 12, CYAN)
	_bar_morale = ProgressBar.new()
	_bar_morale.custom_minimum_size = Vector2(104, 6)
	_bar_morale.show_percentage = false
	_bar_morale.add_theme_stylebox_override("background", _flat_style(Color(0.08, 0.09, 0.11, 0.9), Color.TRANSPARENT, 0, 3))
	_bar_morale.add_theme_stylebox_override("fill", _flat_style(CYAN, Color.TRANSPARENT, 0, 3))
	mbox.add_child(_bar_morale)
	_lbl_conquest = _label(th, "", 13, GOLD)
	_lbl_patience = _label(th, "", 13, MUTED)

	_buffs_box = HBoxContainer.new()
	_buffs_box.position = Vector2(14, 60)
	_buffs_box.add_theme_constant_override("separation", 6)
	_buffs_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_buffs_box)

	var util := HBoxContainer.new()
	util.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	util.offset_left = -356; util.offset_top = 12; util.offset_right = -14; util.offset_bottom = 44
	util.alignment = BoxContainer.ALIGNMENT_END
	util.add_theme_constant_override("separation", 6)
	add_child(util)
	_button(util, "战录(L)", _toggle_logs, GOLD)
	_button(util, "简则(H)", _toggle_rules, CYAN)
	_btn_mute = _button(util, "音效", _toggle_mute, CYAN)
	_btn_pool = _button(util, "完整池", _toggle_pool, GOLD)
	_button(util, "重开", func(): _play_sfx("click"); _restart(true), GOLD)

	# 10. 左下角轻量化战报与隐藏关入口
	var bot_left := VBoxContainer.new()
	bot_left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bot_left.offset_left = 16; bot_left.offset_top = -126; bot_left.offset_right = 330; bot_left.offset_bottom = -16
	bot_left.alignment = BoxContainer.ALIGNMENT_END
	bot_left.add_theme_constant_override("separation", 6)
	add_child(bot_left)
	_hidden_box = HBoxContainer.new()
	_hidden_box.add_theme_constant_override("separation", 6)
	bot_left.add_child(_hidden_box)
	var tick_box := PanelContainer.new()
	tick_box.add_theme_stylebox_override("panel", _flat_style(Color(0.03, 0.04, 0.05, 0.78), Color(0.35, 0.29, 0.2, 0.55), 8, 6))
	bot_left.add_child(tick_box)
	_lbl_ticker = _label(tick_box, "", 12, Color("#dde8e8"))
	_lbl_ticker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# 11. 三幕过场电影横幅
	_act_banner = PanelContainer.new()
	_act_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_act_banner.offset_left = -220; _act_banner.offset_top = 66; _act_banner.offset_right = 220; _act_banner.offset_bottom = 136
	_act_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_act_banner.add_theme_stylebox_override("panel", _flat_style(Color(0.03, 0.04, 0.055, 0.9), GOLD, 10, 6))
	_act_banner.visible = false
	add_child(_act_banner)
	var abv := VBoxContainer.new()
	abv.alignment = BoxContainer.ALIGNMENT_CENTER
	abv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_act_banner.add_child(abv)
	_act_banner_title = _label(abv, "", 20, GOLD)
	_act_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_act_banner_sub = _label(abv, "", 12, CYAN)
	_act_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 12. 统一青铜雕花模态弹窗（事件 / 含CG终局档案 / 名臣替换 / 推演简则 / 战局实录）
	_modal_shade = ColorRect.new()
	_modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_shade.color = Color(0.01, 0.015, 0.022, 0.78)
	_modal_shade.hide()
	add_child(_modal_shade)

	_event_panel = _make_modal(Vector2(540, 310))
	var ev_box := VBoxContainer.new()
	ev_box.add_theme_constant_override("separation", 10)
	_event_panel.add_child(ev_box)
	_label(ev_box, "突发急报  /  历史 × 科技", 12, CYAN)
	_event_title = _label(ev_box, "", 20, GOLD)
	_event_desc = _label(ev_box, "", 14, Color("#e4e9e9"))
	_event_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_event_btn_a = _button(ev_box, "", func(): _play_sfx("click"); _event_panel.hide(); core.resolve_event("A"), GOLD)
	_event_btn_b = _button(ev_box, "", func(): _play_sfx("click"); _event_panel.hide(); core.resolve_event("B"), CYAN)

	_ending_panel = _make_modal(Vector2(610, 520))
	var end_box := VBoxContainer.new()
	end_box.add_theme_constant_override("separation", 9)
	_ending_panel.add_child(end_box)
	_ending_cg = TextureRect.new()
	_ending_cg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ending_cg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_ending_cg.custom_minimum_size = Vector2(540, 210)
	end_box.add_child(_ending_cg)
	var end_top := HBoxContainer.new()
	end_box.add_child(end_top)
	_label(end_top, "大秦终局史官档案", 12, CYAN).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ending_grade = _label(end_top, "", 20, GOLD)
	_ending_title = _label(end_box, "", 22, GOLD)
	_ending_desc = _label(end_box, "", 13, Color("#ebeaea"))
	_ending_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_stats = _label(end_box, "", 12, CYAN)
	_ending_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var end_btns := HBoxContainer.new()
	end_btns.add_theme_constant_override("separation", 10)
	end_box.add_child(end_btns)
	var btn_re := _button(end_btns, "再启推演", func(): _play_sfx("chime"); _restart(true), GOLD)
	btn_re.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_home := _button(end_btns, "返回主屏", func(): _play_sfx("click"); _show_title_curtain(), CYAN)
	btn_home.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_replace_panel = _make_modal(Vector2(520, 290))
	var rep_box := VBoxContainer.new()
	rep_box.add_theme_constant_override("separation", 10)
	_replace_panel.add_child(rep_box)
	_label(rep_box, "名臣席位已满（上限 2 位）", 12, CYAN)
	_replace_title = _label(rep_box, "", 19, GOLD)
	_label(rep_box, "请选择一位离场名臣：", 13, MUTED)
	_replace_btn_0 = _button(rep_box, "", _confirm_replace.bind(0), GOLD)
	_replace_btn_1 = _button(rep_box, "", _confirm_replace.bind(1), GOLD)
	_button(rep_box, "取消召唤", _cancel_replace, MUTED)

	_rules_panel = _make_modal(Vector2(580, 350))
	var r_box := VBoxContainer.new()
	r_box.add_theme_constant_override("separation", 9)
	_rules_panel.add_child(r_box)
	_label(r_box, "咸阳推演简则  /  30 秒上手", 12, CYAN)
	_label(r_box, "守万民之心，望千年未来", 20, GOLD)
	var r_txt := _label(r_box,
		"1. 民心既是血条也是货币：军事外挂降维平推但扣民心；民生科技回民心；民心归零立刻大泽乡起义失败。\n" +
		"2. 12 回合平定六洲：每回合拥有 2 次行动（买卡/召名臣/造楼船/探隐藏关）+ 1 次免费常规进攻。\n" +
		"3. 首回合高光福利：第 1 回合首次召唤【名臣】或拍出【无人机蜂群】免民心；点击沙盘发光点即可出兵，双击快攻。\n" +
		"4. 快捷键：1 / 2 / 3 选用手牌 · R 刷新终端 · L 战局实录 · H 规则简则 · Esc 取消瞄准。",
		13, Color("#e2ecec"))
	r_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r_txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_button(r_box, "明白了，继续推演", _toggle_rules, GOLD)

	_log_panel = _make_modal(Vector2(580, 420))
	var l_box := VBoxContainer.new()
	l_box.add_theme_constant_override("separation", 8)
	_log_panel.add_child(l_box)
	_label(l_box, "咸阳机要战录  /  最近 14 条结算记录", 12, CYAN)
	_log_text = _label(l_box, "", 12, Color("#ddeaea"))
	_log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_button(l_box, "关闭战录 (L)", _toggle_logs, GOLD)

	# 13. 电影感开场主屏幕布
	_title_curtain = Control.new()
	_title_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_title_curtain)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.018, 0.025, 0.72)
	_title_curtain.add_child(shade)
	var tbox := PanelContainer.new()
	tbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	tbox.offset_left = -280; tbox.offset_top = -175; tbox.offset_right = 280; tbox.offset_bottom = 175
	tbox.add_theme_stylebox_override("panel", _plaque_style(36, 30))
	_title_curtain.add_child(tbox)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 12)
	tbox.add_child(tv)
	var k1 := _label(tv, "2026 OSGJ · 望秦社 · 主题「守·望」", 12, CYAN)
	k1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var k2 := _label(tv, "大秦：2076", 40, GOLD)
	k2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var k3 := _label(tv, "公元前 221 年，你携未来推演终端坠落咸阳宫。\n始皇立下 12 回合赌约：平定六洲、守住民心，成则封万世国师，败则斩首。", 13, Color("#d8e4e6"))
	k3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	k3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tbtns := HBoxContainer.new()
	tbtns.alignment = BoxContainer.ALIGNMENT_CENTER
	tbtns.add_theme_constant_override("separation", 14)
	tv.add_child(tbtns)
	var b_start := _button(tbtns, "⚔ 入座推演", _enter_game, GOLD)
	b_start.custom_minimum_size = Vector2(160, 44)
	b_start.add_theme_font_size_override("font_size", 17)
	b_start.add_theme_color_override("font_color", GOLD)
	var b_rules := _button(tbtns, "📜 推演简则", func(): _play_sfx("click"); _enter_game(); _toggle_rules(), CYAN)
	b_rules.custom_minimum_size = Vector2(140, 44)

	_layout_dynamic_elements()


func _enter_game() -> void:
	if not _title_curtain.visible:
		return
	_play_sfx("chime")
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title_curtain, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func():
		_title_curtain.visible = false
		_title_curtain.modulate.a = 1.0
		_show_act_banner(1)
		_animate_hand_deal()
	)


func _show_title_curtain() -> void:
	_ending_panel.hide()
	_event_panel.hide()
	_replace_panel.hide()
	_rules_panel.hide()
	_log_panel.hide()
	_sync_modal_shade()
	_title_curtain.modulate.a = 0.0
	_title_curtain.visible = true
	create_tween().tween_property(_title_curtain, "modulate:a", 1.0, 0.35)


func _toggle_rules() -> void:
	_play_sfx("click")
	_log_panel.hide()
	_rules_panel.visible = not _rules_panel.visible
	_sync_modal_shade()


func _toggle_logs() -> void:
	_play_sfx("click")
	_rules_panel.hide()
	_log_panel.visible = not _log_panel.visible
	if _log_panel.visible:
		var arr: Array = _latest.get("logs", [])
		var slice := arr.slice(maxi(0, arr.size() - 14), arr.size())
		_log_text.text = "\n".join(slice) if not slice.is_empty() else "暂无战局记录。"
	_sync_modal_shade()


func _show_act_banner(act_num: int) -> void:
	if not ACT_TITLES.has(act_num):
		return
	_act_banner_title.text = ACT_TITLES[act_num][0]
	_act_banner_sub.text = ACT_TITLES[act_num][1]
	_act_banner.visible = true
	_act_banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_act_banner, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.7)
	tw.tween_property(_act_banner, "modulate:a", 0.0, 0.45)
	tw.tween_callback(_act_banner.hide)


func _make_modal(sz: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -sz.x * 0.5; p.offset_top = -sz.y * 0.5
	p.offset_right = sz.x * 0.5; p.offset_bottom = sz.y * 0.5
	p.add_theme_stylebox_override("panel", _plaque_style(34, 28))
	p.visible = false
	add_child(p)
	return p


func _get_bg_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var scale_f := maxf(vp.x / 1280.0, vp.y / 720.0) * 1.045
	var sz := Vector2(1280.0, 720.0) * scale_f
	var origin := (vp - sz) * 0.5
	return Rect2(origin, sz)


func _uv_to_stage(uv: Vector2) -> Vector2:
	var r := _get_bg_rect()
	return r.position + Vector2(uv.x * r.size.x, uv.y * r.size.y)


func _layout_dynamic_elements() -> void:
	if _bg_rect == null:
		return
	var r := _get_bg_rect()
	_bg_rect.position = r.position
	_bg_rect.size = r.size
	_crt_status.position = _uv_to_stage(Vector2(0.818, 0.485))
	_crt_status.size = Vector2(138, 68)
	_layout_hand_cards()


func _process(delta: float) -> void:
	_anim_time += delta
	var vp := get_viewport_rect().size
	if vp.x > 0 and vp.y > 0:
		var m := get_viewport().get_mouse_position()
		var norm := Vector2((m.x / vp.x) * 2.0 - 1.0, (m.y / vp.y) * 2.0 - 1.0).clamp(Vector2(-1, -1), Vector2(1, 1))
		_parallax_cur = _parallax_cur.lerp(Vector2(-norm.x * 13.0, -norm.y * 7.0), minf(1.0, delta * 5.0))

		var stage_m := m - _stage.position
		var found := ""
		var found_h := ""
		if not _modal_shade.visible and not _title_curtain.visible:
			var hvis_p: Dictionary = _latest.get("hidden_visible", {})
			for hid in UV_HIDDEN.keys():
				if bool(hvis_p.get(hid, false)) and _uv_to_stage(UV_HIDDEN[hid]).distance_to(stage_m) <= 22.0:
					found_h = hid
					break
			if found_h == "":
				for rid in UV_REGIONS.keys():
					if _uv_to_stage(UV_REGIONS[rid]).distance_to(stage_m) <= 26.0:
						found = rid
						break
		_hovered_region = found
		_hovered_hidden = found_h

	var shake := Vector2.ZERO
	if _shake_strength > 0.2:
		shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
		_shake_strength = maxf(0.0, _shake_strength - delta * 26.0)
	_stage.position = _parallax_cur + shake

	for em in _embers:
		em["life"] = float(em["life"]) + delta * float(em["speed"])
		if float(em["life"]) >= 1.0:
			em["life"] = 0.0
			em["drift"] = randf_range(-0.028, 0.028)

	for i in range(2):
		var hp := _uv_to_stage(UV_ADVISORS[i])
		var bob := sin(_anim_time * 2.3 + float(i) * 1.7) * 5.0
		_holo_rects[i].position = hp - _holo_rects[i].size * 0.5 + Vector2(0.0, bob)
		_holo_names[i].position = Vector2(hp.x - 60.0, hp.y + 84.0 + bob * 0.4)
		_holo_names[i].size = Vector2(120.0, 22.0)
		if _bubble_timers[i] > 0.0:
			_bubble_timers[i] -= delta
			_bubbles[i].position = (hp + _stage.position + Vector2(-105.0, -135.0)).clamp(Vector2(14, 62), vp - Vector2(230, 180))
			if _bubble_timers[i] <= 0.0:
				_bubbles[i].visible = false

	for idx in range(_projectiles.size() - 1, -1, -1):
		var pr: Dictionary = _projectiles[idx]
		pr["t"] = float(pr["t"]) + delta / 0.28
		if float(pr["t"]) >= 1.0:
			_pulses.append({"pos": pr["end"], "col": pr["col"], "t": 0.0, "max_r": 96.0 if pr["big"] else 46.0})
			if pr.get("triple", false):
				_pulses.append({"pos": pr["end"], "col": Color.WHITE, "t": -0.12, "max_r": 128.0})
			_projectiles.remove_at(idx)
	for idx in range(_pulses.size() - 1, -1, -1):
		var pu: Dictionary = _pulses[idx]
		pu["t"] = float(pu["t"]) + delta / 0.54
		if float(pu["t"]) >= 1.0:
			_pulses.remove_at(idx)

	if _popover.visible and UV_REGIONS.has(_selected):
		var sp := _uv_to_stage(UV_REGIONS[_selected]) + _stage.position
		var px := clampf(sp.x + 28.0, 16.0, vp.x - _popover.size.x - 18.0)
		var py := clampf(sp.y - _popover.size.y * 0.5, 66.0, vp.y - _popover.size.y - 210.0)
		_popover.position = Vector2(px, py).round()

	_stage_fx.queue_redraw()


func _draw_stage_fx() -> void:
	if _latest.is_empty():
		return
	var morale: int = int(_latest.get("morale", 60))
	var patience: int = int(_latest.get("patience", 12))
	var low := morale < 40

	# 0. 高台秦始皇压迫感呼吸光晕（耐心 <= 3 时转为猩红威压）
	var epos := _uv_to_stage(UV_EMPEROR)
	var e_urgent := patience <= 3
	var e_col := CRIMSON if e_urgent else Color("#8f6b2e")
	var e_pulse := 0.5 + 0.5 * sin(_anim_time * (4.2 if e_urgent else 1.4))
	_stage_fx.draw_circle(epos, 78.0 + 14.0 * e_pulse, Color(e_col, 0.12 if e_urgent else 0.045))

	# 1. 左侧青铜鼎动态火光脉动 + 全场烛火飘散火星
	var cpos := _uv_to_stage(UV_CAULDRON)
	var flicker := 0.88 + 0.12 * sin(_anim_time * 7.5) + 0.07 * cos(_anim_time * 13.0)
	var fire_col := CRIMSON if low else Color("#ffae42")
	var fire_r := (36.0 + float(morale) * 0.42) * flicker
	_stage_fx.draw_circle(cpos, fire_r, Color(fire_col, 0.14))
	_stage_fx.draw_circle(cpos, fire_r * 0.55, Color(fire_col, 0.24))

	for em in _embers:
		var life: float = float(em["life"])
		var src: Vector2 = em["src"]
		var uv := src + Vector2(float(em["drift"]) * life + sin(_anim_time * 2.5 + float(em["phase"])) * 0.006, -life * 0.14)
		var alpha := sin(life * PI) * 0.72
		_stage_fx.draw_circle(_uv_to_stage(uv), float(em["size"]) * (1.0 - life * 0.4), Color(fire_col, alpha))

	# 2. 咸阳本土微光点 + 6 大板块纯发光玄黑/鎏金印记点 + 受损迷你血条
	var cap := _uv_to_stage(UV_XIANYANG)
	_stage_fx.draw_circle(cap, 12.0 + 2.0 * sin(_anim_time * 3.0), Color(GOLD, 0.2))
	_stage_fx.draw_circle(cap, 4.5, GOLD)

	var font := theme.default_font
	for r in _latest.regions:
		var rid: String = r["id"]
		if not UV_REGIONS.has(rid):
			continue
		var p := _uv_to_stage(UV_REGIONS[rid])
		var conquered: bool = bool(r["conquered"])
		var can_hit: bool = _pending_cheat_slot >= 0 or core.can_attack_region(rid)
		var is_hov: bool = (rid == _hovered_region or rid == _selected)
		var col := GOLD if conquered else (CYAN if can_hit else Color("#8f8370"))

		if conquered:
			var orig_uv: Vector2 = UV_REGIONS.get(r["prereq"], UV_XIANYANG)
			_stage_fx.draw_line(_uv_to_stage(orig_uv), p, Color(GOLD, 0.65), 2.0, true)
			_stage_fx.draw_circle(p, 38.0, Color(GOLD, 0.08))
			_stage_fx.draw_circle(p, 22.0, Color(GOLD, 0.15))
			_stage_fx.draw_circle(p, 9.5, Color(0.06, 0.05, 0.04, 0.94))
			_stage_fx.draw_arc(p, 11.0, 0.0, TAU, 24, GOLD, 2.0, true)
			_stage_fx.draw_string(font, p + Vector2(-6, 4), "秦", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
		else:
			var pulse := 1.0 + 0.15 * sin(_anim_time * 4.5) if (can_hit or is_hov) else 1.0
			var rad := (13.0 if is_hov else 9.0) * pulse
			_stage_fx.draw_circle(p, rad + 4.0, Color(col, 0.16 if is_hov else 0.08))
			_stage_fx.draw_circle(p, 5.0, col)
			_stage_fx.draw_arc(p, rad, 0.0, TAU, 24, Color(col, 0.9), 2.0 if is_hov else 1.4, true)

			# 受损板块自动显示极简迷你血条（一眼掌握战局）
			var hp: int = int(r["hp"])
			var max_hp: int = maxi(1, int(r["max_hp"]))
			if hp < max_hp or is_hov:
				var bw := 36.0
				var bx := p.x - bw * 0.5
				var by := p.y + rad + 5.0
				_stage_fx.draw_rect(Rect2(bx, by, bw, 4.0), Color(0.05, 0.07, 0.09, 0.9))
				_stage_fx.draw_rect(Rect2(bx, by, bw * (float(hp) / float(max_hp)), 4.0), col)

			if is_hov or can_hit:
				var tag := "%s %d" % [r["name"], hp]
				if _pending_cheat_slot >= 0 and is_hov:
					var dmg := _card_damage(_latest.terminal_cards[_pending_cheat_slot].data, hp)
					tag += " → %d" % maxi(0, hp - dmg)
				var tsize := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
				var tpos := p + Vector2(-tsize.x * 0.5, -rad - 8.0)
				_stage_fx.draw_string(font, tpos + Vector2(1, 1), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.95))
				_stage_fx.draw_string(font, tpos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD if is_hov else Color("#d9f8ff"))

	# 3. 三大隐藏关异常微光点（支持沙盘直接悬停辨识与点击触发「望」）
	var hvis: Dictionary = _latest.get("hidden_visible", {})
	for hid in hvis.keys():
		if bool(hvis[hid]) and UV_HIDDEN.has(hid):
			var hp := _uv_to_stage(UV_HIDDEN[hid])
			var hcol := CRIMSON if hid == "dazexiang" else CYAN
			var is_hh: bool = hid == _hovered_hidden
			var hr := (10.5 if is_hh else 7.0) + 3.0 * sin(_anim_time * 6.0)
			_stage_fx.draw_circle(hp, hr, Color(hcol, 0.48 if is_hh else 0.32))
			_stage_fx.draw_arc(hp, hr + 4.0, 0.0, TAU, 20, GOLD if is_hh else hcol, 2.2 if is_hh else 1.6, true)
			if is_hh:
				var htag: String = HIDDEN_HINTS.get(hid, "✦ 异常微光 · 点击探索")
				var hsz := font.get_string_size(htag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
				var htp := hp + Vector2(-hsz.x * 0.5, -hr - 10.0)
				_stage_fx.draw_string(font, htp + Vector2(1, 1), htag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.95))
				_stage_fx.draw_string(font, htp, htag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)

	# 4. 飞行打击弹道与扩散冲击波
	for pr in _projectiles:
		var t: float = clampf(float(pr["t"]), 0.0, 1.0)
		var s: Vector2 = pr["start"]
		var e: Vector2 = pr["end"]
		var m: Vector2 = (s + e) * 0.5 + Vector2(0.0, -90.0)
		var cur := (1.0 - t) * (1.0 - t) * s + 2.0 * (1.0 - t) * t * m + t * t * e
		var trail_t := maxf(0.0, t - 0.18)
		var prev := (1.0 - trail_t) * (1.0 - trail_t) * s + 2.0 * (1.0 - trail_t) * trail_t * m + trail_t * trail_t * e
		_stage_fx.draw_line(prev, cur, pr["col"], 3.5, true)
		_stage_fx.draw_circle(cur, 7.0, pr["col"])

	for pu in _pulses:
		var t: float = float(pu["t"])
		if t < 0.0:
			continue
		t = clampf(t, 0.0, 1.0)
		var r_now: float = lerpf(8.0, float(pu["max_r"]), 1.0 - pow(1.0 - t, 2.0))
		var alpha: float = (1.0 - t) * 0.85
		_stage_fx.draw_arc(pu["pos"], r_now, 0.0, TAU, 32, Color(pu["col"], alpha), 3.0 * (1.0 - t) + 1.0, true)

	# 5. 瞄准指向卡动态战术弧线
	if _pending_cheat_slot >= 0 and _pending_cheat_slot < _card_nodes.size():
		var card_n := _card_nodes[_pending_cheat_slot]
		var start_p := card_n.position + Vector2(card_n.size.x * 0.5, 10.0) - _stage.position
		var end_p := get_viewport().get_mouse_position() - _stage.position
		var snapped := false
		if _hovered_region != "" and UV_REGIONS.has(_hovered_region):
			end_p = _uv_to_stage(UV_REGIONS[_hovered_region])
			snapped = true
		var mid_p := (start_p + end_p) * 0.5 + Vector2(0.0, -70.0)
		var prev := start_p
		var lcol := GOLD if snapped else CYAN
		for step in range(1, 22):
			var t := float(step) / 21.0
			var q := (1.0 - t) * (1.0 - t) * start_p + 2.0 * (1.0 - t) * t * mid_p + t * t * end_p
			_stage_fx.draw_line(prev, q, Color(lcol, 0.88), 2.5, true)
			prev = q
		_stage_fx.draw_arc(end_p, 16.0 + 3.5 * sin(_anim_time * 8.0), 0.0, TAU, 28, lcol, 2.2, true)


func _unhandled_input(event: InputEvent) -> void:
	if _title_curtain.visible:
		if event.is_action_pressed("ui_accept"):
			_enter_game()
			get_viewport().set_input_as_handled()
		return
	if _rules_panel.visible and (event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_H)):
		_toggle_rules()
		get_viewport().set_input_as_handled()
		return
	if _log_panel.visible and (event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_L)):
		_toggle_logs()
		get_viewport().set_input_as_handled()
		return
	if _replace_panel.visible and event.is_action_pressed("ui_cancel"):
		_cancel_replace()
		get_viewport().set_input_as_handled()
		return
	if _modal_shade.visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				if _latest.terminal_cards.size() > 0:
					_use_card(0)
					get_viewport().set_input_as_handled()
					return
			KEY_2:
				if _latest.terminal_cards.size() > 1:
					_use_card(1)
					get_viewport().set_input_as_handled()
					return
			KEY_3:
				if _latest.terminal_cards.size() > 2:
					_use_card(2)
					get_viewport().set_input_as_handled()
					return
			KEY_R:
				if not _btn_refresh.disabled:
					_play_sfx("click"); _cancel_aim(); _result(core.refresh_terminal())
					get_viewport().set_input_as_handled()
					return
			KEY_H:
				_toggle_rules()
				get_viewport().set_input_as_handled()
				return
			KEY_L:
				_toggle_logs()
				get_viewport().set_input_as_handled()
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
		var stage_m: Vector2 = event.position - _stage.position
		var hvis_c: Dictionary = _latest.get("hidden_visible", {})
		for hid in UV_HIDDEN.keys():
			if bool(hvis_c.get(hid, false)) and _uv_to_stage(UV_HIDDEN[hid]).distance_to(stage_m) <= 22.0:
				_play_sfx("click"); _cancel_aim(); _result(core.trigger_hidden(hid))
				get_viewport().set_input_as_handled()
				return
		for rid in UV_REGIONS.keys():
			if _uv_to_stage(UV_REGIONS[rid]).distance_to(stage_m) <= 26.0:
				_on_region_clicked(rid)
				get_viewport().set_input_as_handled()
				return
		if _popover.visible and not _popover.get_global_rect().has_point(event.position):
			_selected = ""
			_popover.hide()


func _restart(show_banner: bool = true) -> void:
	_pending_cheat_slot = -1
	_pending_replace_card_slot = -1
	_selected = ""
	_hovered_region = ""
	_prev_morale = 60
	_prev_patience = 12
	_prev_act = 0
	_last_cards_sig = ""
	_hidden_triggered_count = 0
	_popover.hide()
	_ending_panel.hide()
	_event_panel.hide()
	_replace_panel.hide()
	_rules_panel.hide()
	_log_panel.hide()
	_modal_shade.hide()
	for i in range(2):
		_bubbles[i].hide()
		_bubble_timers[i] = 0.0
	core.init_game(_game_data, _lines_data, _mvp_only)
	if show_banner and not _title_curtain.visible:
		_show_act_banner(1)


func _toggle_pool() -> void:
	_play_sfx("click")
	_mvp_only = not _mvp_only
	_btn_pool.text = "精简池" if _mvp_only else "完整池"
	_restart(true)


func _sync_modal_shade() -> void:
	_modal_shade.visible = (
		_event_panel.visible
		or _ending_panel.visible
		or _replace_panel.visible
		or _rules_panel.visible
		or _log_panel.visible
		or (not _latest.is_empty() and (not _latest.pending_event.is_empty() or _latest.game_over_code != ""))
	)


func _cards_signature(cards: Array) -> String:
	var parts := []
	for c in cards:
		parts.append("%s:%s" % [c.kind, c.data.id])
	return "|".join(parts)


func _on_state_changed(snap: Dictionary) -> void:
	var old_m := _prev_morale
	var old_p := _prev_patience
	var old_act := _prev_act
	var is_first := _latest.is_empty()
	_latest = snap
	_prev_morale = int(snap["morale"])
	_prev_patience = int(snap["patience"])
	_prev_act = int(snap["act"])
	_sync_modal_shade()

	if not is_first:
		var dm := _prev_morale - old_m
		var dp := _prev_patience - old_p
		if dm > 0:
			_pulses.append({"pos": _uv_to_stage(UV_XIANYANG), "col": GOLD, "t": 0.0, "max_r": 72.0})
			_spawn_float_text(_uv_to_stage(UV_XIANYANG), "+%d 民心" % dm, SAGE)
		if dp > 0:
			_pulses.append({"pos": _uv_to_stage(UV_XIANYANG), "col": CYAN, "t": 0.0, "max_r": 64.0})
			_spawn_float_text(_uv_to_stage(UV_XIANYANG) + Vector2(0, -28), "+%d 耐心" % dp, GOLD)
		if old_act > 0 and _prev_act > old_act and not _title_curtain.visible:
			_play_sfx("chime")
			_show_act_banner(_prev_act)

	_lbl_act.text = "第 %d 回合 · 第 %d 幕" % [snap["turn"], snap["act"]]
	var low := _prev_morale < 40
	_lbl_morale.text = "%s民心 %d/%d" % ["⚠ " if low else "", _prev_morale, int(snap["morale_cap"])]
	_lbl_morale.modulate = CRIMSON if low else CYAN
	_bar_morale.max_value = int(snap["morale_cap"])
	_bar_morale.value = _prev_morale
	_bar_morale.add_theme_stylebox_override("fill", _flat_style(CRIMSON if low else CYAN, Color.TRANSPARENT, 0, 3))
	_lbl_conquest.text = "统一 %d/6" % int(snap["conquered_count"])
	_lbl_patience.text = "%s始皇耐心 %d" % ["⚠ " if _prev_patience <= 3 else "", _prev_patience]
	_lbl_patience.modulate = CRIMSON if _prev_patience <= 3 else MUTED
	_crt_status.text = "TERMINAL_2076\n行动 %s\n常规进攻 %d/1" % ["●".repeat(snap["actions_left"]) + "○".repeat(2 - snap["actions_left"]), int(snap["attack_left"])]
	_vignette_mat.set_shader_parameter("danger_intensity", 1.0 if low else 0.0)

	# 声音作为玩法信息源：第三幕切换紧张战鼓；民心 < 40 时起义喧哗随 (40 - 民心) 线性放大
	if _bgm_player != null and not _audio_muted:
		var want_bgm: AudioStream = _bgm_act3_stream if (_prev_act >= 3 and _bgm_act3_stream != null) else _bgm_ambient_stream
		if want_bgm != null and _bgm_player.stream != want_bgm:
			_bgm_player.stream = want_bgm
			_bgm_player.play()
	if _uprising_player != null and _uprising_player.stream != null:
		if low and not _audio_muted:
			var intensity := clampf(float(40 - _prev_morale) / 40.0, 0.0, 1.0)
			_uprising_player.volume_db = lerpf(-26.0, -7.0, intensity)
			if not _uprising_player.playing:
				_uprising_player.play()
		else:
			if _uprising_player.playing:
				_uprising_player.stop()

	_refresh_buff_pills(snap)

	# 更新两位全息名臣立绘及悬停技能提示
	var advs: Array = snap["advisors"]
	for i in range(2):
		if i < advs.size():
			var p_path: String = advs[i].get("portrait", "")
			if p_path != "" and ResourceLoader.exists(p_path):
				_holo_rects[i].texture = load(p_path)
			_holo_rects[i].tooltip_text = "【%s】常驻技能：%s" % [advs[i]["name"], advs[i]["skill"]]
			_holo_rects[i].visible = true
			_holo_names[i].text = "【%s】" % advs[i]["name"]
			_holo_names[i].visible = true
		else:
			_holo_rects[i].visible = false
			_holo_names[i].visible = false

	# 更新隐藏关快捷按钮
	for ch in _hidden_box.get_children():
		ch.queue_free()
	var hvis: Dictionary = snap["hidden_visible"]
	for hid in hvis.keys():
		if bool(hvis[hid]):
			var hname := str({"penglai":"蓬莱仙岛", "dazexiang":"大泽乡暗流", "antarctica":"南极时间舱"}.get(hid, hid))
			var hb := _button(_hidden_box, "✦ " + hname, func(): _play_sfx("click"); _cancel_aim(); _result(core.trigger_hidden(hid)), GOLD)
			hb.add_theme_color_override("font_color", GOLD)

	if bool(snap.get("free_hook_available", false)):
		_lbl_ticker.text = "★ 首回合高光：下方首次召唤【名臣】或拍出【无人机蜂群】免民心；点击沙盘发光点可直接出兵。"
	elif _lbl_ticker.text == "":
		_lbl_ticker.text = "点击沙盘发光点查看守军并出兵，按 1/2/3 快捷键可快速抬牌。"

	var new_sig := _cards_signature(snap["terminal_cards"])
	var should_deal := (new_sig != _last_cards_sig) and not _title_curtain.visible
	_last_cards_sig = new_sig
	_rebuild_hand_cards(should_deal)
	_refresh_popover()


func _refresh_buff_pills(snap: Dictionary) -> void:
	for ch in _buffs_box.get_children():
		ch.queue_free()
	var items := []
	if int(snap["conventional_power"]) > 20:
		items.append(["⚔ 秦军战力 %d" % int(snap["conventional_power"]), GOLD])
	if bool(snap["sea_unlocked"]):
		items.append(["🌊 远洋通航", CYAN])
	if int(snap["cyber_burn_turns"]) > 0:
		items.append(["🔒 民心锁死 %d回合" % int(snap["cyber_burn_turns"]), VIOLET])
	if int(snap["loan_remaining"]) > 0:
		items.append(["⏳ 贷款偿还 %d回合" % int(snap["loan_remaining"]), CRIMSON])
	if bool(snap["penicillin_turn"]):
		items.append(["💊 南亚效率 1.0", SAGE])
	if bool(snap["education_turn"]):
		items.append(["📚 义务教育·本回禁攻", GOLD])
	for it in items:
		var pill := PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_theme_stylebox_override("panel", _flat_style(Color(0.04, 0.055, 0.07, 0.84), Color(it[1], 0.75), 5, 5))
		_buffs_box.add_child(pill)
		var lbl := _label(pill, it[0], 11, it[1])
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _rebuild_hand_cards(animate_deal: bool = false) -> void:
	for n in _card_nodes:
		n.queue_free()
	_card_nodes.clear()
	_card_base_pos.clear()

	_btn_cancel_aim.visible = _pending_cheat_slot >= 0
	_btn_refresh.text = "刷新终端 %d/3 (−%d)" % [_latest.refreshes_left, core.get_refresh_cost()]
	_btn_refresh.disabled = _latest.refreshes_left <= 0 or _latest.overheat_no_refresh
	_btn_fleet.text = "渡海航线已通" if _latest.sea_unlocked else "强征造楼船 (−%d)" % core.get_fleet_cost()
	_btn_fleet.disabled = _latest.sea_unlocked or _latest.actions_left <= 0

	for i in range(_latest.terminal_cards.size()):
		var cnode := _create_tactile_card(i)
		_hand_layer.add_child(cnode)
		_card_nodes.append(cnode)
	_layout_hand_cards()
	if animate_deal:
		_animate_hand_deal()


func _animate_hand_deal() -> void:
	var origin := _uv_to_stage(UV_CRT) + _stage.position - Vector2(90, 90)
	for i in range(_card_nodes.size()):
		if i >= _card_base_pos.size():
			break
		var n := _card_nodes[i]
		var target_pos := _card_base_pos[i]
		var target_rot := _card_base_rot[i]
		n.position = origin
		n.scale = Vector2(0.35, 0.35)
		n.rotation_degrees = 18.0
		n.modulate.a = 0.0
		var tw := n.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(float(i) * 0.065)
		tw.tween_property(n, "position", target_pos, 0.28)
		tw.parallel().tween_property(n, "scale", Vector2.ONE, 0.28)
		tw.parallel().tween_property(n, "rotation_degrees", target_rot, 0.28)
		tw.parallel().tween_property(n, "modulate:a", 1.0, 0.16)


func _layout_hand_cards() -> void:
	if _card_nodes.is_empty():
		return
	var vp := get_viewport_rect().size
	var card_sz := Vector2(182.0, 212.0)
	var gap := 16.0
	var count := _card_nodes.size()
	var total_w := float(count) * card_sz.x + float(count - 1) * gap
	var start_x := (vp.x - total_w) * 0.5 - 24.0
	var base_y := vp.y - card_sz.y + 14.0
	_card_base_pos.clear()
	for i in range(count):
		var arch_y := absf(float(i) - 1.0) * 8.0
		var pos := Vector2(start_x + float(i) * (card_sz.x + gap), base_y + arch_y)
		_card_base_pos.append(pos)
		var n := _card_nodes[i]
		n.size = card_sz
		n.pivot_offset = card_sz * 0.5
		var lifted: bool = (i == _pending_cheat_slot)
		n.position = pos + (Vector2(0, -28) if lifted else Vector2.ZERO)
		n.rotation_degrees = 0.0 if lifted else _card_base_rot[i]
		n.z_index = 12 if lifted else i


func _create_tactile_card(slot: int) -> Control:
	var card: Dictionary = _latest.terminal_cards[slot]
	var data: Dictionary = card.data
	var advisor: bool = card.kind == "advisor"
	var kind: String = "名臣" if advisor else {"military":"军事", "livelihood":"民生", "blacktech":"奇术"}[data.category]
	var tint: Color = {"军事":CYAN, "民生":SAGE, "奇术":VIOLET, "名臣":GOLD}[kind]
	var is_free: bool = (not card.bought) and bool(_latest.get("free_hook_available", false)) and (advisor or data.id == "drone")
	var delta := -core.get_effective_advisor_cost(data) if advisor else core.get_effective_cheat_delta(data)
	if delta < 0 and _latest.cyber_burn_turns > 0:
		delta = 0
	var badge := "★ 免费" if is_free else ("已部署" if card.bought else ("%+d" % delta if delta != 0 else "免耗"))
	var disabled: bool = card.bought or _latest.actions_left <= 0 or (data.id == "education" and _latest.attack_left <= 0)
	var active: bool = (slot == _pending_cheat_slot)

	var root := Control.new()
	root.custom_minimum_size = Vector2(182, 212)

	var frame := TextureRect.new()
	frame.texture = _tex_card
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate = Color(1.18, 1.12, 1.0, 1.0) if (active or is_free) else (Color(0.55, 0.55, 0.58, 0.72) if disabled else Color.WHITE)
	root.add_child(frame)

	var rim := ColorRect.new()
	rim.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rim.offset_left = 18; rim.offset_top = 12; rim.offset_right = -18; rim.offset_bottom = 15
	rim.color = GOLD if is_free else tint
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rim)

	var body := VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 18; body.offset_top = 19; body.offset_right = -18; body.offset_bottom = -16
	body.add_theme_constant_override("separation", 4)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(body)

	var top_r := HBoxContainer.new()
	top_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(top_r)
	var kl := _label(top_r, "[%d] %s" % [slot + 1, kind], 11, tint)
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := _label(top_r, badge, 13, GOLD if is_free else (SAGE if delta > 0 else (CRIMSON if delta < 0 else MUTED)))
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var art_tex: Texture2D = null
	if advisor and ResourceLoader.exists(data.portrait):
		art_tex = load(data.portrait)
	elif not advisor and _category_icons.has(data.category):
		art_tex = _category_icons[data.category]
	if art_tex != null:
		var pr := TextureRect.new()
		pr.texture = art_tex
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pr.custom_minimum_size = Vector2(58, 58)
		pr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(pr)

	var tl := _label(body, data.name, 16, Color.WHITE)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var desc: String = data.skill if advisor else data.desc
	if not advisor and data.needs_target:
		var punch := "秒杀任意板块" if data.id == "nuke_seal" or (data.id == "drone" and core.has_advisor("huoqubing")) else "%d 战力打击" % _card_damage(data, 0)
		desc = punch + (" · 通航" if data.id == "ironclad" else "")
	var dl := _label(body, desc, 11, MUTED)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if disabled:
		body.modulate = Color(0.6, 0.62, 0.64, 0.78)

	var hit := Button.new()
	hit.flat = true
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.disabled = disabled
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.pressed.connect(_use_card.bind(slot))
	hit.mouse_entered.connect(func():
		if not disabled and slot < _card_base_pos.size():
			_play_sfx("hover")
			root.z_index = 20
			var tw := root.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(root, "position", _card_base_pos[slot] + Vector2(0, -32), 0.14)
			tw.parallel().tween_property(root, "rotation_degrees", 0.0, 0.14)
			tw.parallel().tween_property(root, "scale", Vector2(1.07, 1.07), 0.14)
	)
	hit.mouse_exited.connect(func():
		if slot != _pending_cheat_slot and slot < _card_base_pos.size():
			root.z_index = slot
			var tw := root.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(root, "position", _card_base_pos[slot], 0.14)
			tw.parallel().tween_property(root, "rotation_degrees", _card_base_rot[slot], 0.14)
			tw.parallel().tween_property(root, "scale", Vector2.ONE, 0.14)
	)
	root.add_child(hit)
	return root


func _card_damage(data: Dictionary, hp: int) -> int:
	if data.id == "nuke_seal" or (data.id == "drone" and core.has_advisor("huoqubing")):
		return hp
	return int(data.damage) * (2 if core.has_advisor("caocao") else 1)


func _use_card(slot: int) -> void:
	if _modal_shade.visible or _title_curtain.visible:
		return
	var card: Dictionary = _latest.terminal_cards[slot]
	if card.bought or _latest.actions_left <= 0:
		return
	_play_sfx("click")
	if card.kind == "cheat" and card.data.needs_target:
		_pending_cheat_slot = -1 if _pending_cheat_slot == slot else slot
		_popover.hide()
		_rebuild_hand_cards(false)
		return
	_pending_cheat_slot = -1
	if card.kind == "advisor":
		if core.advisors.size() >= 2:
			_open_replace_dialog(slot, card.data)
		else:
			var res := core.summon_advisor(slot, -1)
			if res.get("ok", false):
				_play_sfx("summon")
				_pulses.append({"pos": _uv_to_stage(UV_XIANYANG), "col": CYAN, "t": 0.0, "max_r": 64.0})
			_result(res)
	else:
		var res := core.buy_cheat(slot)
		if res.get("ok", false):
			_play_sfx("summon")
			if card.data.id == "cyber_burn":
				_screen_flash(VIOLET, 0.32, 0.38)
				_pulses.append({"pos": _uv_to_stage(UV_XIANYANG), "col": VIOLET, "t": 0.0, "max_r": 74.0})
				_spawn_float_text(_uv_to_stage(UV_XIANYANG), "民心锁死 2 回合", VIOLET)
			elif card.data.id == "rice":
				_screen_flash(GOLD, 0.22, 0.35)
			elif card.data.id == "ak47" or card.data.id == "cement_road":
				_pulses.append({"pos": _uv_to_stage(UV_XIANYANG), "col": GOLD, "t": 0.0, "max_r": 70.0})
				_spawn_float_text(_uv_to_stage(UV_XIANYANG), "秦军常规战力强化！", GOLD)
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


func _confirm_replace(idx: int) -> void:
	_play_sfx("click")
	var slot := _pending_replace_card_slot
	_pending_replace_card_slot = -1
	_replace_panel.hide()
	_sync_modal_shade()
	if slot >= 0:
		var res := core.summon_advisor(slot, idx)
		if res.get("ok", false):
			_play_sfx("summon")
		_result(res)


func _cancel_replace() -> void:
	_play_sfx("click")
	_pending_replace_card_slot = -1
	_replace_panel.hide()
	_sync_modal_shade()


func _cancel_aim() -> void:
	if _pending_cheat_slot != -1:
		_pending_cheat_slot = -1
		_rebuild_hand_cards(false)


func _on_region_clicked(id: String) -> void:
	if _modal_shade.visible or _title_curtain.visible:
		return
	_play_sfx("click")
	if _pending_cheat_slot >= 0:
		var slot := _pending_cheat_slot
		_pending_cheat_slot = -1
		var res := core.buy_cheat(slot, id)
		if not res.get("ok", false):
			_pending_cheat_slot = slot
			_result(res)
		_rebuild_hand_cards(false)
		return
	if _selected == id and _popover.visible and core.can_attack_region(id) and _latest.attack_left > 0 and not _latest.education_turn:
		_result(core.conventional_attack(id))
		return
	_selected = id
	_refresh_popover()


func _refresh_popover() -> void:
	_popover.hide()
	if _selected == "" or _pending_cheat_slot >= 0 or _latest.is_empty():
		return
	for r in _latest.regions:
		if r["id"] != _selected:
			continue
		_popover.show()
		_pop_title.text = "%s · %s" % [r["name"], "已归玄黑" if r["conquered"] else "守军 %d/%d" % [int(r["hp"]), int(r["max_hp"])]]
		if r["conquered"]:
			_pop_desc.text = r["reward"]
			_pop_attack.hide()
		else:
			var ready := core.can_attack_region(r["id"])
			var eff := 1.0 if r["id"] == "south_asia" and _latest.penicillin_turn else float(r["efficiency"])
			var dmg := floori(eff * _latest.conventional_power)
			_pop_attack.show()
			_pop_attack.text = "⚔ 常规进攻 (−%d 战力)" % dmg
			_pop_attack.disabled = not ready or _latest.attack_left <= 0 or _latest.education_turn
			if not ready:
				_pop_desc.text = "需先开通渡海航线（造楼船或跨海铁甲舰）。" if r["requires_sea"] else "需先攻克前置板块。"
			elif _latest.education_turn:
				_pop_desc.text = "本回合已推行义务教育，无法常规进攻。"
			elif _latest.attack_left <= 0:
				_pop_desc.text = "本回合常规进攻已用完，可用下方军事手牌。"
			else:
				_pop_desc.text = "%s（再次点击据点直接出兵）" % r["reward"]


func _spawn_float_text(stage_pos: Vector2, text: String, col: Color) -> void:
	var lbl := _label(_stage, text, 22, col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position = stage_pos + Vector2(-46.0, -30.0)
	var tw := lbl.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", lbl.position.y - 42.0, 0.55)
	tw.tween_interval(0.35)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3)
	tw.tween_callback(lbl.queue_free)


func _result(res: Dictionary) -> void:
	if not res.get("ok", false):
		_lbl_ticker.text = "⚠ " + str(res.get("error", "操作未完成"))


func _on_strike_performed(region_id: String, damage: int, source: String, conquered: bool) -> void:
	var is_nuke := damage >= 500 or source.find("玉玺") >= 0
	_play_sfx("conquer" if conquered else "strike")
	_shake_strength = 22.0 if is_nuke else (11.0 if conquered else 5.5)
	if is_nuke:
		_screen_flash(GOLD, 0.58, 0.48)
	elif conquered:
		_screen_flash(GOLD, 0.22, 0.28)
	if UV_REGIONS.has(region_id):
		var target := _uv_to_stage(UV_REGIONS[region_id])
		_projectiles.append({"start": _uv_to_stage(UV_XIANYANG), "end": target, "col": GOLD if (conquered or is_nuke) else CYAN, "t": 0.0, "big": conquered or is_nuke, "triple": is_nuke})
		var region: Dictionary = _latest.regions.filter(func(r): return r.id == region_id)[0]
		var loss := mini(damage, int(region.hp))
		_spawn_float_text(target, "−%d%s" % [loss, " ★攻克" if conquered else ""], GOLD if conquered else CYAN)
		_lbl_ticker.text = "%s 命中【%s】−%d · %s" % [source, region.name, loss, "已染玄黑！" if conquered else "守军剩余 %d" % (int(region.hp) - loss)]
	if conquered:
		_popover.hide()


func _on_advisor_spoke(aid: String, advisor_name: String, line: String) -> void:
	var idx := 0
	var advs: Array = _latest.get("advisors", [])
	for i in range(advs.size()):
		if advs[i].get("id", "") == aid:
			idx = i
			break
	if idx < _bubbles.size():
		_bubble_labels[idx].text = "【%s】「%s」" % [advisor_name, line]
		_bubbles[idx].visible = true
		_bubble_timers[idx] = 4.8
	_lbl_ticker.text = "【%s】「%s」" % [advisor_name, line]


func _on_hidden_triggered(hidden_id: String, reward_text: String) -> void:
	_hidden_triggered_count += 1
	_play_sfx("summon")
	_screen_flash(CYAN, 0.25, 0.35)
	_pulses.append({"pos": _uv_to_stage(UV_XIANYANG), "col": GOLD, "t": 0.0, "max_r": 74.0})
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
	var won := code.begins_with("win_")
	var is_sage := (code == "win_sage")
	_play_sfx("victory" if is_sage else "defeat")
	_screen_flash(GOLD if is_sage else CRIMSON, 0.42, 0.5)
	_popover.hide()
	if code == "win_sage":
		_ending_cg.texture = _tex_end_win
	elif code == "win_tyrant":
		_ending_cg.texture = _tex_end_tyrant
	else:
		_ending_cg.texture = _tex_end_lose

	var grade := "C · 历史回响"
	if code == "win_sage" and _prev_morale >= 80:
		grade = "S · 盛世千古"
	elif code == "win_sage":
		grade = "A · 守望大同"
	elif code == "win_tyrant":
		grade = "B · 赛博霸业"

	var adv_names := []
	for a in _latest.get("advisors", []):
		adv_names.append(a["name"])
	var roster := "、".join(adv_names) if not adv_names.is_empty() else "孤身推演"

	_ending_grade.text = "评级 %s" % grade
	_ending_title.text = "%s" % data.get("title", "终局")
	_ending_desc.text = "%s" % data.get("prompt", "")
	_ending_stats.text = "本局战报：历时 %d 回合 · 统一 %d/6 洲 · 终局民心 %d · 隐藏探索 %d 次\n在场名臣：%s" % [
		int(_latest.get("turn", 1)),
		int(_latest.get("conquered_count", 0)),
		_prev_morale,
		_hidden_triggered_count,
		roster,
	]
	_ending_panel.show()
	_sync_modal_shade()
