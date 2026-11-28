extends Control
## 《大秦：2076》2.5D 咸阳宫暗黑立体桌面与拟物手牌表现层（v3.2 · 国师秘技炸场与始皇密匣版）
## 严格遵循逻辑与表现分离：仅调用 GameCore 公开方法并订阅信号，不反向篡改核心状态。

var core := GameCore.new()
var _game_data: Dictionary = {}
var _lines_data: Dictionary = {}
var _mvp_only: bool = false
var _tactical_mode: bool = true

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
	"paradox_core": Vector2(0.585, 0.525),
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
	4: ["终幕 · 2076 焚书协议", "历史修正率 100% — 未来终端已接管咸阳沙盘"],
}

# 贴图缓存
var _tex_bg: Texture2D
var _tex_card: Texture2D
var _tex_panel: Texture2D
var _tex_end_win: Texture2D
var _tex_end_tyrant: Texture2D
var _tex_end_lose: Texture2D
var _category_icons: Dictionary = {}
var _landmarks: Dictionary = {}

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
var _zoom_cur: float = 1.0
var _focus_offset_cur := Vector2.ZERO
var _shake_strength: float = 0.0
var _projectiles: Array[Dictionary] = []
var _pulses: Array[Dictionary] = []
var _embers: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _hp_ghost: Dictionary = {}
var _hitstop_timer: float = 0.0
var _emperor_glare_timer: float = 0.0
var _crt_glitch_timer: float = 0.0
var _hovered_prop: String = ""

# 拖拽甩牌状态（兼容点击与快捷键）
var _drag_slot: int = -1
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_active: bool = false


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
var _used_nuke: bool = false
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
var _pop_img: TextureRect
var _pop_art_holder: Control
var _pop_badge: Label
var _pop_title: Label
var _pop_sub: Label
var _pop_bar: ProgressBar
var _pop_desc: Label
var _pop_attack: Button
var _crt_status: Label
var _lbl_act: Label
var _lbl_morale: Label
var _bar_morale: ProgressBar
var _lbl_conquest: Label
var _lbl_patience: Label
var _buffs_box: HBoxContainer
var _threat_label: Label
var _lbl_ticker: Label
var _btn_refresh: Button
var _btn_fleet: Button
var _btn_pool: Button
var _btn_mute: Button
var _btn_cancel_aim: Button
var _btn_pact: Button
var _secret_box: HBoxContainer
var _pact_panel: PanelContainer
var _pact_btn_a: Button
var _pact_btn_b: Button
var _hidden_box: HBoxContainer
var _act_banner: PanelContainer
var _act_banner_title: Label
var _act_banner_sub: Label
var _guide_bar: PanelContainer
var _guide_lbl: Label
var _banner_tween: Tween
var _cutin_tween: Tween
var _cutin_bar: PanelContainer
var _cutin_pic_l: TextureRect
var _cutin_pic_r: TextureRect
var _cutin_title: Label
var _cutin_sub: Label
var _meta_save: Dictionary = {"summoned": [], "endings": [], "wins": 0, "runs": 0, "best_grade": "", "tutorial_done": false}
var _title_curtain: Control
var _rules_panel: PanelContainer
var _log_panel: PanelContainer
var _log_text: Label
var _codex_panel: PanelContainer
var _codex_grid: GridContainer
var _codex_scroll: ScrollContainer
var _codex_tab_adv: Button
var _codex_tab_cheat: Button
var _codex_tab_lands: Button
var _codex_mode: String = "advisors"
var _modal_shade: ColorRect
var _modal_layer := CanvasLayer.new()
var _event_panel: PanelContainer
var _event_img: TextureRect
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
var _ending_ach: Label
var _hidden_panel: PanelContainer
var _hidden_img: TextureRect
var _hidden_title: Label
var _hidden_desc: Label
var _hidden_reward: Label
var _replace_panel: PanelContainer
var _replace_title: Label
var _replace_btn_0: Button
var _replace_btn_1: Button
var _debate_panel: PanelContainer
var _debate_pic_a: TextureRect
var _debate_pic_b: TextureRect
var _debate_name_a: Label
var _debate_name_b: Label
var _debate_quote_a: Label
var _debate_quote_b: Label
var _debate_btn_a: Button
var _debate_btn_b: Button


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
	for lid in ["xianyang", "steppe", "west", "south_asia", "west_asia", "europe", "americas", "paradox_core"]:
		var lp := "res://assets/landmarks/%s.jpg" % lid
		if ResourceLoader.exists(lp):
			_landmarks[lid] = load(lp)

	_init_embers()
	_setup_audio()
	_build_stage_and_ui()

	core.state_changed.connect(_on_state_changed)
	core.strike_performed.connect(_on_strike_performed)
	core.event_triggered.connect(_on_event_triggered)
	core.advisor_spoke.connect(_on_advisor_spoke)
	core.hidden_triggered.connect(_on_hidden_triggered)
	core.game_ended.connect(_on_game_ended)
	core.threat_interrupted.connect(_on_threat_interrupted)
	core.synergy_activated.connect(_on_synergy_activated)
	core.decree_completed.connect(_on_decree_completed)
	core.debate_triggered.connect(_on_debate_triggered)
	core.weakness_hit.connect(_on_weakness_hit)
	core.secret_card_gained.connect(_on_secret_card_gained)
	core.pact_made.connect(_on_pact_made)
	core.boss_phase_triggered.connect(_on_boss_phase_triggered)
	core.paradox_awakened.connect(_on_paradox_awakened)

	_load_meta_save()
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


func _plaque_style(pad_x: int = 60, pad_y: int = 46) -> StyleBoxTexture:
	var st := StyleBoxTexture.new()
	st.texture = _tex_panel
	st.texture_margin_left = 86
	st.texture_margin_right = 86
	st.texture_margin_top = 64
	st.texture_margin_bottom = 64
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
		tr.mouse_filter = Control.MOUSE_FILTER_PASS
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

	# 6. 地图就地实景建筑战区勘察牌（青铜雕花贴图 + 16:9 实景建筑大图）
	_popover = PanelContainer.new()
	_popover.visible = false
	_popover.add_theme_stylebox_override("panel", _plaque_style(36, 30))
	add_child(_popover)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	_popover.add_child(pv)
	var p_hdr := HBoxContainer.new()
	pv.add_child(p_hdr)
	_pop_title = _label(p_hdr, "", 16, GOLD)
	_pop_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p_close := _button(p_hdr, "✕", func(): _play_sfx("click"); _selected = ""; _popover.hide(), MUTED)
	p_close.custom_minimum_size = Vector2(28, 26)
	var img_wrap := PanelContainer.new()
	img_wrap.add_theme_stylebox_override("panel", _flat_style(Color(0.02, 0.03, 0.04, 0.95), Color(0.55, 0.43, 0.24, 0.8), 2, 4))
	pv.add_child(img_wrap)
	_pop_art_holder = Control.new()
	_pop_art_holder.custom_minimum_size = Vector2(316, 178)
	img_wrap.add_child(_pop_art_holder)
	_pop_img = TextureRect.new()
	_pop_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pop_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pop_img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pop_art_holder.add_child(_pop_img)
	var badge_bg := PanelContainer.new()
	badge_bg.position = Vector2(8, 8)
	badge_bg.add_theme_stylebox_override("panel", _flat_style(Color(0.03, 0.04, 0.055, 0.86), GOLD, 5, 4))
	_pop_art_holder.add_child(badge_bg)
	_pop_badge = _label(badge_bg, "", 11, GOLD)
	_pop_sub = _label(pv, "", 12, CYAN)
	_pop_bar = ProgressBar.new()
	_pop_bar.custom_minimum_size = Vector2(316, 7)
	_pop_bar.show_percentage = false
	_pop_bar.add_theme_stylebox_override("background", _flat_style(Color(0.07, 0.09, 0.11, 0.92), Color.TRANSPARENT, 0, 3))
	_pop_bar.add_theme_stylebox_override("fill", _flat_style(CYAN, Color.TRANSPARENT, 0, 3))
	pv.add_child(_pop_bar)
	_pop_desc = _label(pv, "", 12, Color("#d4e1e2"))
	_pop_desc.custom_minimum_size.x = 316
	_pop_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pop_attack = _button(pv, "⚔ 常规进攻", func(): _play_sfx("click"); _result(core.conventional_attack(_selected)), GOLD)

	# 7. 底部中央扇形实体手牌层 + 悬停在手牌上方的 0 费金色国师秘技栏
	_hand_layer = Control.new()
	_hand_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_layer)

	_secret_box = HBoxContainer.new()
	_secret_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_secret_box.offset_left = -260; _secret_box.offset_top = -272; _secret_box.offset_right = 212; _secret_box.offset_bottom = -230
	_secret_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_secret_box.add_theme_constant_override("separation", 10)
	add_child(_secret_box)

	# 8. 右下角 CRT 终端指令按键组
	var crt_cmds := VBoxContainer.new()
	crt_cmds.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	crt_cmds.offset_left = -224; crt_cmds.offset_top = -212; crt_cmds.offset_right = -18; crt_cmds.offset_bottom = -16
	crt_cmds.add_theme_constant_override("separation", 7)
	add_child(crt_cmds)

	_btn_cancel_aim = _button(crt_cmds, "✕ 取消瞄准 (Esc)", func(): _play_sfx("click"); _cancel_aim(), CRIMSON)
	_btn_cancel_aim.visible = false
	_btn_refresh = _button(crt_cmds, "", func(): _play_sfx("click"); _cancel_aim(); _result(core.refresh_terminal()), CYAN)
	_btn_fleet = _button(crt_cmds, "", func(): _play_sfx("click"); _cancel_aim(); _result(core.build_fleet()), GOLD)
	_btn_pact = _button(crt_cmds, "🔥 始皇密匣（限1次）", _open_pact_modal, CRIMSON)
	_btn_pact.add_theme_color_override("font_color", GOLD)
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
	_lbl_act.mouse_filter = Control.MOUSE_FILTER_STOP
	_lbl_act.tooltip_text = "按已统一大洲数推进幕次：0~1洲第1幕 · 2~3洲第2幕 · 4~5洲第3幕"
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

	var status_rows := VBoxContainer.new()
	status_rows.position = Vector2(14, 60)
	status_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_rows.add_theme_constant_override("separation", 4)
	add_child(status_rows)
	_buffs_box = HBoxContainer.new()
	_buffs_box.add_theme_constant_override("separation", 6)
	_buffs_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_rows.add_child(_buffs_box)
	_threat_label = _label(status_rows, "", 13, Color.WHITE, false)
	_threat_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_threat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_threat_label.add_theme_color_override("font_color", Color("#ffb5aa"))
	_threat_label.add_theme_stylebox_override("normal", _flat_style(Color("#231419"), CRIMSON, 6, 5))
	_threat_label.hide()

	var util := HBoxContainer.new()
	util.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	util.offset_left = -436; util.offset_top = 12; util.offset_right = -14; util.offset_bottom = 44
	util.alignment = BoxContainer.ALIGNMENT_END
	util.add_theme_constant_override("separation", 6)
	add_child(util)
	_button(util, "图鉴(C)", _toggle_codex, GOLD)
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

	# 11b. 首回合 3 步轻引导浮条（不遮挡操作，完成或点击跳过后自动隐藏）
	_guide_bar = PanelContainer.new()
	_guide_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_guide_bar.offset_left = -280; _guide_bar.offset_top = 144; _guide_bar.offset_right = 280; _guide_bar.offset_bottom = 182
	_guide_bar.add_theme_stylebox_override("panel", _flat_style(Color(0.05, 0.08, 0.10, 0.92), GOLD, 10, 6))
	_guide_bar.visible = false
	add_child(_guide_bar)
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 10)
	_guide_bar.add_child(gh)
	_guide_lbl = _label(gh, "", 13, GOLD)
	_guide_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gskip := _button(gh, "跳过", func():
		_guide_bar.visible = false
		_meta_save["tutorial_done"] = true
		_save_meta_save()
	, MUTED)
	gskip.custom_minimum_size = Vector2(48, 24)

	# 12. 统一青铜雕花模态弹窗（事件 / 含CG终局档案 / 名臣替换 / 推演简则 / 战局实录）
	# Hand cards use local z_index for their fan and hover. Keep all dialogs above that canvas.
	_modal_layer.layer = 1
	add_child(_modal_layer)
	_modal_shade = ColorRect.new()
	_modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_shade.color = Color(0.01, 0.015, 0.022, 0.78)
	_modal_shade.hide()
	_modal_layer.add_child(_modal_shade)

	# 11c. 羁绊 / 秘技双名臣立绘切入横幅（Cut-in，不拦截鼠标）
	_cutin_bar = PanelContainer.new()
	_cutin_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cutin_bar.offset_left = -360; _cutin_bar.offset_top = -76; _cutin_bar.offset_right = 360; _cutin_bar.offset_bottom = 76
	_cutin_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin_bar.add_theme_stylebox_override("panel", _flat_style(Color(0.03, 0.04, 0.06, 0.94), GOLD, 12, 10))
	_cutin_bar.visible = false
	_modal_layer.add_child(_cutin_bar)
	var cih := HBoxContainer.new()
	cih.alignment = BoxContainer.ALIGNMENT_CENTER
	cih.add_theme_constant_override("separation", 18)
	cih.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin_bar.add_child(cih)
	_cutin_pic_l = TextureRect.new()
	_cutin_pic_l.custom_minimum_size = Vector2(108, 108)
	_cutin_pic_l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cutin_pic_l.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cutin_pic_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cih.add_child(_cutin_pic_l)
	var civ := VBoxContainer.new()
	civ.alignment = BoxContainer.ALIGNMENT_CENTER
	civ.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	civ.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cih.add_child(civ)
	_cutin_title = _label(civ, "", 24, GOLD)
	_cutin_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cutin_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin_sub = _label(civ, "", 13, Color("#e8f6f8"))
	_cutin_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cutin_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cutin_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin_pic_r = TextureRect.new()
	_cutin_pic_r.custom_minimum_size = Vector2(108, 108)
	_cutin_pic_r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cutin_pic_r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cutin_pic_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cih.add_child(_cutin_pic_r)

	_event_panel = _make_modal(Vector2(650, 520))
	var ev_box := VBoxContainer.new()
	ev_box.add_theme_constant_override("separation", 9)
	_event_panel.add_child(ev_box)
	_event_img = TextureRect.new()
	_event_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_event_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_event_img.custom_minimum_size = Vector2(520, 200)
	ev_box.add_child(_event_img)
	_label(ev_box, "突发急报  /  历史 × 科技", 12, CYAN)
	_event_title = _label(ev_box, "", 20, GOLD)
	_event_desc = _label(ev_box, "", 14, Color("#e4e9e9"))
	_event_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_event_btn_a = _button(ev_box, "", func(): _play_sfx("click"); _event_panel.hide(); core.resolve_event("A"), GOLD)
	_event_btn_b = _button(ev_box, "", func(): _play_sfx("click"); _event_panel.hide(); core.resolve_event("B"), CYAN)

	_ending_panel = _make_modal(Vector2(680, 595))
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
	_ending_ach = _label(end_box, "", 13, GOLD)
	_ending_ach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_ach.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var end_btns := HBoxContainer.new()
	end_btns.add_theme_constant_override("separation", 10)
	end_box.add_child(end_btns)
	var btn_re := _button(end_btns, "再启推演", func(): _play_sfx("chime"); _restart(true), GOLD)
	btn_re.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_home := _button(end_btns, "返回主屏", func(): _play_sfx("click"); _show_title_curtain(), CYAN)
	btn_home.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_hidden_panel = _make_modal(Vector2(650, 505))
	var h_box := VBoxContainer.new()
	h_box.add_theme_constant_override("separation", 9)
	_hidden_panel.add_child(h_box)
	_hidden_img = TextureRect.new()
	_hidden_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hidden_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hidden_img.custom_minimum_size = Vector2(520, 205)
	h_box.add_child(_hidden_img)
	_label(h_box, "✦ 守望秘境 · 隐藏奇观触发", 12, CYAN)
	_hidden_title = _label(h_box, "", 21, GOLD)
	_hidden_desc = _label(h_box, "", 13, Color("#e4eeee"))
	_hidden_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hidden_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hidden_reward = _label(h_box, "", 15, SAGE)
	_button(h_box, "收入囊中，继续推演", func(): _play_sfx("click"); _hidden_panel.hide(); _sync_modal_shade(), GOLD)

	_replace_panel = _make_modal(Vector2(590, 340))
	var rep_box := VBoxContainer.new()
	rep_box.add_theme_constant_override("separation", 10)
	_replace_panel.add_child(rep_box)
	_label(rep_box, "名臣席位已满（上限 2 位）", 12, CYAN)
	_replace_title = _label(rep_box, "", 19, GOLD)
	_label(rep_box, "请选择一位离场名臣：", 13, MUTED)
	_replace_btn_0 = _button(rep_box, "", _confirm_replace.bind(0), GOLD)
	_replace_btn_1 = _button(rep_box, "", _confirm_replace.bind(1), GOLD)
	_button(rep_box, "取消召唤", _cancel_replace, MUTED)

	_debate_panel = _make_modal(Vector2(690, 455))
	var db_box := VBoxContainer.new()
	db_box.add_theme_constant_override("separation", 10)
	_debate_panel.add_child(db_box)
	_label(db_box, "⚡ 朝堂争辩  /  在场名臣当庭争执，请陛下定夺", 12, CYAN)
	var db_cols := HBoxContainer.new()
	db_cols.add_theme_constant_override("separation", 16)
	db_cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	db_box.add_child(db_cols)
	for side_idx in range(2):
		var col_p := PanelContainer.new()
		col_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col_p.add_theme_stylebox_override("panel", _flat_style(Color(0.04, 0.055, 0.07, 0.9), GOLD if side_idx == 0 else CYAN, 10, 6))
		db_cols.add_child(col_p)
		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 6)
		col_p.add_child(cv)
		var pic := TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(86, 86)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(pic)
		var nm := _label(cv, "", 16, GOLD if side_idx == 0 else CYAN)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var qt := _label(cv, "", 12, Color("#ddeaea"))
		qt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		qt.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if side_idx == 0:
			_debate_pic_a = pic; _debate_name_a = nm; _debate_quote_a = qt
		else:
			_debate_pic_b = pic; _debate_name_b = nm; _debate_quote_b = qt
	_debate_btn_a = _button(db_box, "", func(): _play_sfx("click"); _debate_panel.hide(); core.resolve_debate("A"), GOLD)
	_debate_btn_b = _button(db_box, "", func(): _play_sfx("click"); _debate_panel.hide(); core.resolve_debate("B"), CYAN)

	_pact_panel = _make_modal(Vector2(650, 400))
	var p_box := VBoxContainer.new()
	p_box.add_theme_constant_override("separation", 10)
	_pact_panel.add_child(p_box)
	_label(p_box, "🔥 始皇密匣  /  打破规则的暗黑献祭（每局限 1 次）", 12, CRIMSON)
	_label(p_box, "「既入咸阳局，便须以代价换天命。」", 19, GOLD)
	var p_desc := _label(p_box, "高台阴影中的秦始皇向你推来一只玄黑密匣。你可以献祭自身根基，强行改写本局铁律：", 13, Color("#e2ecec"))
	p_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pact_btn_a = _button(p_box, "", func(): _play_sfx("event"); _pact_panel.hide(); _sync_modal_shade(); _result(core.make_emperor_pact("sacrifice")), CRIMSON)
	_pact_btn_b = _button(p_box, "B. 盗取天时：本局民心上限永久 -25 → 始皇耐心 +4 回合，并获赠 1 张 0 费金色国师秘技", func(): _play_sfx("event"); _pact_panel.hide(); _sync_modal_shade(); _result(core.make_emperor_pact("steal_time")), GOLD)
	_button(p_box, "合上密匣，暂不交易 (Esc)", func(): _play_sfx("click"); _pact_panel.hide(); _sync_modal_shade(), MUTED)

	_rules_panel = _make_modal(Vector2(650, 400))
	var r_box := VBoxContainer.new()
	r_box.add_theme_constant_override("separation", 9)
	_rules_panel.add_child(r_box)
	_label(r_box, "咸阳推演简则  /  30 秒上手", 12, CYAN)
	_label(r_box, "守万民之心，望千年未来", 20, GOLD)
	var r_txt := _label(r_box,
		"1. 民心既是血条也是货币：军事外挂降维平推但扣民心；民生科技回民心；民心归零立刻大泽乡起义失败。\n" +
		"2. 12 回合平定六洲：每回合拥有 2 次行动（买卡/召名臣/造楼船/探隐藏关）+ 1 次免费常规进攻。\n" +
		"3. 首回合高光福利：第 1 回合首次召唤【名臣】或拍出【无人机蜂群】免民心；点击沙盘发光点即可出兵，双击快攻。\n" +
		"4. 快捷键：1 / 2 / 3 选用手牌 · R 刷新终端 · C 卡牌图鉴 · L 战局实录 · H 规则简则 · Esc 取消瞄准。",
		13, Color("#e2ecec"))
	r_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r_txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_button(r_box, "明白了，继续推演", _toggle_rules, GOLD)

	_log_panel = _make_modal(Vector2(650, 450))
	var l_box := VBoxContainer.new()
	l_box.add_theme_constant_override("separation", 8)
	_log_panel.add_child(l_box)
	_label(l_box, "咸阳机要战录  /  最近 14 条结算记录", 12, CYAN)
	var l_scroll := ScrollContainer.new()
	l_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	l_box.add_child(l_scroll)
	_log_text = _label(l_scroll, "", 13, Color("#ddeaea"), false)
	_log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(l_box, "关闭战录 (L)", _toggle_logs, GOLD)

	_codex_panel = _make_modal(Vector2(960, 588))
	_codex_panel.add_theme_stylebox_override("panel", _plaque_style(64, 48))
	var c_box := VBoxContainer.new()
	c_box.add_theme_constant_override("separation", 10)
	_codex_panel.add_child(c_box)
	var c_hdr := HBoxContainer.new()
	c_hdr.add_theme_constant_override("separation", 10)
	c_box.add_child(c_hdr)
	_label(c_hdr, "咸阳藏经阁", 22, GOLD).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_tab_adv = _button(c_hdr, "👑 历史名臣 (18)", func(): _play_sfx("click"); _codex_mode = "advisors"; _populate_codex(), GOLD)
	_codex_tab_cheat = _button(c_hdr, "⚡ 外挂 (12)", func(): _play_sfx("click"); _codex_mode = "cheats"; _populate_codex(), CYAN)
	_codex_tab_lands = _button(c_hdr, "🏛 九州舆图 (7)", func(): _play_sfx("click"); _codex_mode = "landmarks"; _populate_codex(), GOLD)
	_button(c_hdr, "关闭 (C)", _toggle_codex, MUTED)
	_codex_scroll = ScrollContainer.new()
	_codex_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_codex_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c_box.add_child(_codex_scroll)
	_codex_grid = GridContainer.new()
	_codex_grid.columns = 3
	_codex_grid.add_theme_constant_override("h_separation", 12)
	_codex_grid.add_theme_constant_override("v_separation", 12)
	_codex_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_scroll.add_child(_codex_grid)

	# 13. 电影感开场主屏幕布
	_title_curtain = Control.new()
	_title_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.add_child(_title_curtain)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.018, 0.025, 0.72)
	_title_curtain.add_child(shade)
	var tbox := PanelContainer.new()
	tbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	tbox.offset_left = -315; tbox.offset_top = -195; tbox.offset_right = 315; tbox.offset_bottom = 195
	tbox.add_theme_stylebox_override("panel", _plaque_style(64, 48))
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
	var b_codex := _button(tbtns, "📖 卡牌图鉴", func(): _play_sfx("click"); _enter_game(); _toggle_codex(), GOLD)
	b_codex.custom_minimum_size = Vector2(132, 44)
	var b_rules := _button(tbtns, "📜 推演简则", func(): _play_sfx("click"); _enter_game(); _toggle_rules(), CYAN)
	b_rules.custom_minimum_size = Vector2(132, 44)

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
		_update_first_turn_guide(_latest)
		_show_act_banner(1)
		_animate_hand_deal()
	)


func _show_title_curtain() -> void:
	_title_curtain.modulate.a = 0.0
	_title_curtain.visible = true
	_restart(false)
	create_tween().tween_property(_title_curtain, "modulate:a", 1.0, 0.35)


func _toggle_rules() -> void:
	_play_sfx("click")
	_log_panel.hide()
	_codex_panel.hide()
	_rules_panel.visible = not _rules_panel.visible
	_sync_modal_shade()


func _toggle_logs() -> void:
	_play_sfx("click")
	_rules_panel.hide()
	_codex_panel.hide()
	_log_panel.visible = not _log_panel.visible
	if _log_panel.visible:
		var arr: Array = _latest.get("logs", [])
		var slice := arr.slice(maxi(0, arr.size() - 14), arr.size())
		_log_text.text = "\n".join(slice) if not slice.is_empty() else "暂无战局记录。"
	_sync_modal_shade()


func _toggle_codex() -> void:
	_play_sfx("click")
	_rules_panel.hide()
	_log_panel.hide()
	_codex_panel.visible = not _codex_panel.visible
	if _codex_panel.visible:
		_populate_codex()
	_sync_modal_shade()


func _populate_codex() -> void:
	_codex_scroll.scroll_vertical = 0
	for ch in _codex_grid.get_children():
		_codex_grid.remove_child(ch)
		ch.queue_free()
	_codex_tab_adv.modulate = GOLD if _codex_mode == "advisors" else MUTED
	_codex_tab_cheat.modulate = CYAN if _codex_mode == "cheats" else MUTED
	_codex_tab_lands.modulate = GOLD if _codex_mode == "landmarks" else MUTED
	if _codex_mode == "advisors":
		var idx := 1
		for adv in _game_data.get("advisors", []):
			var quote := ""
			var lines_for_adv: Variant = _lines_data.get("advisors", {}).get(adv["id"], {})
			if lines_for_adv is Dictionary:
				for k in lines_for_adv.keys():
					var arr: Variant = lines_for_adv[k]
					if arr is Array and not arr.is_empty():
						quote = "「%s」" % str(arr[0])
						break
			var collected: bool = adv["id"] in _meta_save.get("summoned", [])
			_codex_grid.add_child(_make_codex_card(
				adv["name"], "-%d" % int(adv["cost"]), "★已收录" if collected else "常驻",
				adv["skill"], quote, "- ★ 已收录 -" if collected else "- 玄黑名臣 -", "NO.%02d" % idx,
				GOLD if collected else CYAN, Color("#4a3614") if collected else Color("#24201a"), adv.get("portrait", "")
			))
			idx += 1
	elif _codex_mode == "landmarks":
		_codex_grid.add_child(_make_codex_card(
			"大秦 · 咸阳宫", "秦", "本营",
			"咸阳宫与万里长城：玄黑帝国龙兴之地，当前常规秦军战力 %d。" % int(_latest.get("conventional_power", 20)),
			"点击沙盘本营可随时巡视国力", "- 帝国核心 -", "MAP.00",
			GOLD, Color("#3a2c16"), "res://assets/landmarks/xianyang.jpg"
		))
		var midx := 1
		for r in _latest.get("regions", _game_data.get("regions", [])):
			var conq: bool = bool(r.get("conquered", false))
			var kw := "已平定" if conq else ("守军%d" % int(r.get("hp", 0)))
			var badge := "秦" if conq else "%d" % int(r.get("hp", 0))
			var wk := core.get_region_weakness_info(r["id"])
			_codex_grid.add_child(_make_codex_card(
				r["name"], badge, kw,
				"%s。%s" % [str(r.get("landmark_name", r["coverage"])), r["reward"]],
				"🎯 " + str(wk["label"]), "- 九州舆图 -", "MAP.%02d" % midx,
				GOLD if conq else CYAN, Color("#352718") if conq else Color("#122d36"), r.get("landmark", "")
			))
			midx += 1
	else:
		var cidx := 1
		for ch_d in _game_data.get("cheats", []):
			var cat: String = ch_d["category"]
			var footer: String = {"military":"- 现代军事 -", "livelihood":"- 民生科技 -", "blacktech":"- 奇术黑科 -"}[cat]
			var footer_bg: Color = {"military":Color("#11313a"), "livelihood":Color("#1a3423"), "blacktech":Color("#2c1b3e")}[cat]
			var tint: Color = {"military":CYAN, "livelihood":SAGE, "blacktech":VIOLET}[cat]
			var kw := "限1次" if bool(ch_d.get("one_time", false)) else ("打击" if bool(ch_d.get("needs_target", false)) else "生效")
			var dm: int = int(ch_d["morale_delta"])
			var badge := ("%+d" % dm) if dm != 0 else "0"
			_codex_grid.add_child(_make_codex_card(
				ch_d["name"], badge, kw,
				ch_d["desc"], "", footer, "EXT.%02d" % cidx,
				tint, footer_bg, ch_d.get("art", "")
			))
			cidx += 1


func _make_codex_card(title: String, badge_txt: String, keyword: String, desc: String, quote: String, footer_title: String, code_no: String, tint: Color, footer_bg: Color, art_path: String) -> Control:
	# 仿《王者万象棋》竖版收藏卡排版：上方满幅高清插画+左上角徽章+底居中角色名 / 中部深哑光居中技能框 / 底部阵营彩条
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(264, 376)
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = Color("#13171a")
	outer_style.border_color = Color(tint, 0.55)
	outer_style.set_border_width_all(2)
	outer_style.set_corner_radius_all(8)
	outer_style.shadow_color = Color(0, 0, 0, 0.5)
	outer_style.shadow_size = 6
	card.add_theme_stylebox_override("panel", outer_style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	card.add_child(vb)

	# 1. 上半部满幅插画区（216px 高）
	var art_box := Control.new()
	art_box.custom_minimum_size = Vector2(0, 216)
	art_box.clip_contents = true
	vb.add_child(art_box)

	if art_path != "" and ResourceLoader.exists(art_path):
		var pic := TextureRect.new()
		pic.texture = load(art_path)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art_box.add_child(pic)

	# 插画底部柔和暗化渐晕，衬托居中角色名
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.075, 0.09, 0.102, 0.0), Color(0.075, 0.09, 0.102, 0.96)])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	var fade := TextureRect.new()
	fade.texture = gtex
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	fade.offset_top = -62
	art_box.add_child(fade)

	# 左上角圆形费用/印记徽章
	var b_wrap := PanelContainer.new()
	b_wrap.position = Vector2(10, 10)
	b_wrap.custom_minimum_size = Vector2(40, 40)
	var b_st := StyleBoxFlat.new()
	b_st.bg_color = Color(0.06, 0.08, 0.10, 0.84)
	b_st.border_color = Color(tint, 0.85)
	b_st.set_border_width_all(2)
	b_st.set_corner_radius_all(20)
	b_wrap.add_theme_stylebox_override("panel", b_st)
	art_box.add_child(b_wrap)
	var b_lbl := _label(b_wrap, badge_txt, 13, tint, false)
	b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 插画底部正中央大号角色/卡牌名称
	var name_lbl := _label(art_box, title, 21, Color.WHITE, true)
	name_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_lbl.offset_top = -34
	name_lbl.offset_bottom = -6
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_constant_override("outline_size", 4)
	name_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.06, 0.95))

	# 2. 中部深色哑光居中技能介绍区
	var mid := PanelContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mid_st := StyleBoxFlat.new()
	mid_st.bg_color = Color("#13171a")
	mid_st.content_margin_left = 14
	mid_st.content_margin_right = 14
	mid_st.content_margin_top = 10
	mid_st.content_margin_bottom = 8
	mid.add_theme_stylebox_override("panel", mid_st)
	vb.add_child(mid)

	var mv := VBoxContainer.new()
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_theme_constant_override("separation", 5)
	mid.add_child(mv)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.add_theme_font_size_override("normal_font_size", 13)
	rtl.add_theme_font_size_override("bold_font_size", 13)
	var hex := tint.to_html(false)
	rtl.text = "[center][b][color=#%s]✦ %s：[/color][/b][color=#e6eceb]%s[/color][/center]" % [hex, keyword, desc]
	mv.add_child(rtl)

	if not quote.is_empty():
		var q_lbl := _label(mv, quote, 11, MUTED, false)
		q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# 3. 底部阵营/分类彩色横幅条（左编号 · 中阵营名 · 右水印）
	var foot := PanelContainer.new()
	foot.custom_minimum_size = Vector2(0, 30)
	var f_st := StyleBoxFlat.new()
	f_st.bg_color = footer_bg
	f_st.corner_radius_bottom_left = 6
	f_st.corner_radius_bottom_right = 6
	f_st.content_margin_left = 10
	f_st.content_margin_right = 10
	foot.add_theme_stylebox_override("panel", f_st)
	vb.add_child(foot)

	var fh := HBoxContainer.new()
	foot.add_child(fh)
	var fl := _label(fh, code_no, 10, Color(1, 1, 1, 0.55), false)
	fl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var fc := _label(fh, footer_title, 13, tint, false)
	fc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var fr := _label(fh, "QIN 2076", 10, Color(1, 1, 1, 0.45), false)
	fr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	return card


func _start_banner_animation() -> Tween:
	if _banner_tween:
		_banner_tween.kill()
	_act_banner.add_theme_stylebox_override("panel", _flat_style(Color(0.03, 0.04, 0.055, 0.9), GOLD, 10, 6))
	_act_banner_title.modulate = GOLD
	_banner_tween = _act_banner.create_tween()
	return _banner_tween


func _clear_presentations() -> void:
	if _banner_tween:
		_banner_tween.kill()
	if _cutin_tween:
		_cutin_tween.kill()
	_act_banner.hide()
	_cutin_bar.hide()

func _show_act_banner(act_num: int) -> void:
	if not ACT_TITLES.has(act_num):
		return
	var tw := _start_banner_animation()
	_act_banner_title.text = ACT_TITLES[act_num][0]
	_act_banner_sub.text = ACT_TITLES[act_num][1]
	_act_banner.visible = true
	_act_banner.modulate.a = 0.0
	tw.tween_property(_act_banner, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.7)
	tw.tween_property(_act_banner, "modulate:a", 0.0, 0.45)
	tw.tween_callback(_act_banner.hide)


func _make_modal(sz: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -sz.x * 0.5; p.offset_top = -sz.y * 0.5
	p.offset_right = sz.x * 0.5; p.offset_bottom = sz.y * 0.5
	p.add_theme_stylebox_override("panel", _plaque_style(64, 48))
	p.visible = false
	_modal_layer.add_child(p)
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
	if _hitstop_timer > 0.0:
		_hitstop_timer = maxf(0.0, _hitstop_timer - delta)
		_stage_fx.queue_redraw()
		return
	_anim_time += delta
	if _emperor_glare_timer > 0.0:
		_emperor_glare_timer = maxf(0.0, _emperor_glare_timer - delta)
	if _crt_glitch_timer > 0.0:
		_crt_glitch_timer = maxf(0.0, _crt_glitch_timer - delta)
	var vp := get_viewport_rect().size
	if vp.x > 0 and vp.y > 0:
		var m := get_viewport().get_mouse_position()
		var norm := Vector2((m.x / vp.x) * 2.0 - 1.0, (m.y / vp.y) * 2.0 - 1.0).clamp(Vector2(-1, -1), Vector2(1, 1))
		_parallax_cur = _parallax_cur.lerp(Vector2(-norm.x * 13.0, -norm.y * 7.0), minf(1.0, delta * 5.0))

		var stage_m := (m - _stage.position) / maxf(0.5, _stage.scale.x)
		var found := ""
		var found_h := ""
		if not _modal_shade.visible and not _title_curtain.visible:
			var hvis_p: Dictionary = _latest.get("hidden_visible", {})
			for hid in UV_HIDDEN.keys():
				if bool(hvis_p.get(hid, false)) and _uv_to_stage(UV_HIDDEN[hid]).distance_to(stage_m) <= 22.0:
					found_h = hid
					break
			if found_h == "":
				if _uv_to_stage(UV_XIANYANG).distance_to(stage_m) <= 24.0:
					found = "xianyang"
				else:
					for r_item in _latest.get("regions", []):
						var rid: String = r_item["id"]
						if UV_REGIONS.has(rid) and _uv_to_stage(UV_REGIONS[rid]).distance_to(stage_m) <= (32.0 if rid == "paradox_core" else 26.0):
							found = rid
							break
		_hovered_region = found
		_hovered_hidden = found_h
		var found_prop := ""
		if found == "" and found_h == "" and not _modal_shade.visible and not _title_curtain.visible and not _drag_active:
			found_prop = _tabletop_prop_at(stage_m)
		_hovered_prop = found_prop

	# 拖拽中的卡牌实时跟随指针并带物理倾斜
	if _drag_active and _drag_slot >= 0 and _drag_slot < _card_nodes.size():
		var dn := _card_nodes[_drag_slot]
		var mpos := get_viewport().get_mouse_position()
		var card_info: Dictionary = _latest.terminal_cards[_drag_slot] if _drag_slot < _latest.get("terminal_cards", []).size() else {}
		var is_targeted: bool = (not card_info.is_empty()) and card_info.kind == "cheat" and bool(card_info.data.get("needs_target", false))
		if is_targeted:
			var anchor := _card_base_pos[_drag_slot] + Vector2(0, -48) if _drag_slot < _card_base_pos.size() else dn.position
			dn.position = dn.position.lerp(anchor, minf(1.0, delta * 18.0))
			dn.rotation_degrees = lerpf(dn.rotation_degrees, 0.0, minf(1.0, delta * 16.0))
			dn.scale = dn.scale.lerp(Vector2(1.1, 1.1), minf(1.0, delta * 16.0))
		else:
			var target_p := mpos - dn.size * 0.5
			var vx := target_p.x - dn.position.x
			dn.position = dn.position.lerp(target_p, minf(1.0, delta * 24.0))
			dn.rotation_degrees = lerpf(dn.rotation_degrees, clampf(vx * 0.25, -18.0, 18.0), minf(1.0, delta * 16.0))
			var ready_drop := mpos.y < vp.y * 0.72
			dn.scale = dn.scale.lerp(Vector2(1.12, 1.12) if ready_drop else Vector2(1.05, 1.05), minf(1.0, delta * 16.0))

	# 选中板块或咸阳时平滑推近镜头聚焦该大陆，取消选中时柔和拉回全景
	var target_zoom := 1.0
	var target_focus := Vector2.ZERO
	if _popover.visible and _selected != "" and not _modal_shade.visible and not _title_curtain.visible:
		var f_uv: Vector2 = UV_XIANYANG if _selected == "xianyang" else UV_REGIONS.get(_selected, Vector2(0.5, 0.5))
		target_zoom = 1.13
		var f_pt := _uv_to_stage(f_uv)
		target_focus = (vp * Vector2(0.36, 0.50)) - f_pt * target_zoom
		target_focus = target_focus.clamp(Vector2(-vp.x * 0.22, -vp.y * 0.16), Vector2(vp.x * 0.12, vp.y * 0.10))
	_zoom_cur = lerpf(_zoom_cur, target_zoom, minf(1.0, delta * 5.2))
	_focus_offset_cur = _focus_offset_cur.lerp(target_focus, minf(1.0, delta * 5.2))
	_stage.scale = Vector2(_zoom_cur, _zoom_cur)

	var shake := Vector2.ZERO
	if _shake_strength > 0.2:
		shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
		_shake_strength = maxf(0.0, _shake_strength - delta * 26.0)
	_stage.position = _parallax_cur + _focus_offset_cur + shake

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
		pr["t"] = float(pr["t"]) + delta / 0.24
		if float(pr["t"]) >= 1.0:
			_pulses.append({"pos": pr["end"], "col": pr["col"], "t": 0.0, "max_r": 108.0 if pr["big"] else 54.0})
			_spawn_sparks(pr["end"], pr["col"], 28 if pr["big"] else 14, 240.0 if pr["big"] else 155.0)
			if pr.get("triple", false):
				_pulses.append({"pos": pr["end"], "col": Color.WHITE, "t": -0.10, "max_r": 146.0})
				_spawn_sparks(pr["end"], GOLD, 36, 320.0)
			_projectiles.remove_at(idx)
	for idx in range(_sparks.size() - 1, -1, -1):
		var sp: Dictionary = _sparks[idx]
		sp["life"] = float(sp["life"]) + delta / float(sp["dur"])
		if float(sp["life"]) >= 1.0:
			_sparks.remove_at(idx)
		else:
			var vel: Vector2 = sp["vel"]
			vel.y += float(sp.get("grav", 220.0)) * delta
			sp["vel"] = vel
			sp["pos"] = Vector2(sp["pos"]) + vel * delta
	for r_gh in _latest.get("regions", []):
		var gid: String = r_gh["id"]
		var cur_hp := float(r_gh["hp"])
		if not _hp_ghost.has(gid) or float(_hp_ghost[gid]) < cur_hp:
			_hp_ghost[gid] = cur_hp
		else:
			_hp_ghost[gid] = lerpf(float(_hp_ghost[gid]), cur_hp, minf(1.0, delta * 3.4))
	for idx in range(_pulses.size() - 1, -1, -1):
		var pu: Dictionary = _pulses[idx]
		pu["t"] = float(pu["t"]) + delta / 0.54
		if float(pu["t"]) >= 1.0:
			_pulses.remove_at(idx)

	if _popover.visible and (_selected == "xianyang" or UV_REGIONS.has(_selected)):
		var f_uv: Vector2 = UV_XIANYANG if _selected == "xianyang" else UV_REGIONS[_selected]
		var sp := _uv_to_stage(f_uv) * _stage.scale.x + _stage.position
		var max_panel_height := vp.y - 62.0 - 236.0
		var chrome_height := _popover.get_combined_minimum_size().y - _pop_art_holder.custom_minimum_size.y
		var art_height := clampf(max_panel_height - chrome_height, 80.0, 178.0)
		if _pop_art_holder.custom_minimum_size.y != art_height:
			_pop_art_holder.custom_minimum_size.y = art_height
		_popover.reset_size()
		var px := clampf(sp.x + 32.0, 16.0, vp.x - _popover.size.x - 18.0)
		var py := clampf(sp.y - _popover.size.y * 0.5, 62.0, maxf(62.0, vp.y - _popover.size.y - 236.0))
		_popover.position = Vector2(px, py).round()

	_stage_fx.queue_redraw()


func _draw_stage_fx() -> void:
	if _latest.is_empty():
		return
	var morale: int = int(_latest.get("morale", 60))
	var patience: int = int(_latest.get("patience", 12))
	var low := morale < 40

	# 0. 高台秦始皇压迫感呼吸光晕 + 帝王瞳光（低民心/终幕/点击时骤亮）
	var epos := _uv_to_stage(UV_EMPEROR)
	var e_urgent := patience <= 3 or bool(_latest.get("paradox_phase", false))
	var e_col := CRIMSON if e_urgent else Color("#8f6b2e")
	var e_pulse := 0.5 + 0.5 * sin(_anim_time * (4.2 if e_urgent else 1.4))
	if e_urgent or low or _emperor_glare_timer > 0.0 or _hovered_prop == "emperor":
		var eye_col := CRIMSON if (e_urgent or low) else GOLD
		var eye_a := clampf((0.55 + 0.45 * e_pulse) if (e_urgent or low) else (0.95 if _emperor_glare_timer > 0.0 else 0.55), 0.25, 1.0)
		var eye_l := epos + Vector2(-9.5, -16.0)
		var eye_r := epos + Vector2(9.5, -16.0)
		_stage_fx.draw_circle(eye_l, 7.5, Color(eye_col, eye_a * 0.28))
		_stage_fx.draw_circle(eye_r, 7.5, Color(eye_col, eye_a * 0.28))
		_stage_fx.draw_circle(eye_l, 2.6, Color(eye_col, eye_a))
		_stage_fx.draw_circle(eye_r, 2.6, Color(eye_col, eye_a))
	if _crt_glitch_timer > 0.0:
		var crt_p := _uv_to_stage(UV_CRT)
		for gi in range(4):
			var gy := crt_p.y - 32.0 + float(gi) * 18.0 + randf_range(-4.0, 4.0)
			_stage_fx.draw_line(Vector2(crt_p.x - 52.0, gy), Vector2(crt_p.x + 52.0, gy), Color(CYAN, 0.55), 2.0)
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

	# 2. 咸阳本土微缩宫殿地标 + 6 大板块微缩文明建筑剪影 + 受损迷你血条
	var cap := _uv_to_stage(UV_XIANYANG)
	var cap_hov := (_hovered_region == "xianyang" or _selected == "xianyang")
	_stage_fx.draw_circle(cap, (16.0 if cap_hov else 12.0) + 2.0 * sin(_anim_time * 3.0), Color(GOLD, 0.26 if cap_hov else 0.18))
	_draw_mini_landmark(cap, "xianyang", GOLD)
	if cap_hov:
		var ct := "大秦 · 咸阳宫"
		var csz := theme.default_font.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		_stage_fx.draw_string(theme.default_font, cap + Vector2(-csz.x * 0.5 + 1, -18), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.95))
		_stage_fx.draw_string(theme.default_font, cap + Vector2(-csz.x * 0.5, -19), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)

	var font := theme.default_font
	var active_aim_slot := _pending_cheat_slot
	if _drag_active and _drag_slot >= 0 and _drag_slot < _latest.terminal_cards.size():
		var dragged: Dictionary = _latest.terminal_cards[_drag_slot]
		active_aim_slot = _drag_slot if dragged.kind == "cheat" and dragged.data.needs_target else -1
	for r in _latest.regions:
		var rid: String = r["id"]
		if not UV_REGIONS.has(rid):
			continue
		var p := _uv_to_stage(UV_REGIONS[rid])
		var conquered: bool = bool(r["conquered"])
		var can_hit: bool = active_aim_slot >= 0 or core.can_attack_region(rid)
		var is_hov: bool = (rid == _hovered_region or rid == _selected)
		var is_boss_core: bool = (rid == "paradox_core")
		var col := GOLD if conquered else (CRIMSON if is_boss_core else (CYAN if can_hit else Color("#8f8370")))

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
			_stage_fx.draw_arc(p, rad, 0.0, TAU, 24, Color(col, 0.85), 2.0 if is_hov else 1.4, true)
			_draw_mini_landmark(p, rid, col)
			var thr: Dictionary = _latest.get("active_threat", {})
			if not thr.is_empty() and not bool(thr.get("interrupted", false)) and thr.get("region_id", "") == rid:
				var tpulse := 18.0 + 4.5 * sin(_anim_time * 7.5)
				_stage_fx.draw_arc(p, tpulse, 0.0, TAU, 28, CRIMSON, 2.4, true)

			# 受损板块自动显示极简迷你血条（一眼掌握战局）
			var hp: int = int(r["hp"])
			var max_hp: int = maxi(1, int(r["max_hp"]))
			var lock_hp: int = int(r.get("boss_lock_hp", 0))
			var has_lock_shield: bool = (lock_hp > 0 and not bool(r.get("phase2_triggered", false)))
			if is_boss_core:
				var glitch_r := 22.0 + 5.0 * sin(_anim_time * 9.0)
				_stage_fx.draw_circle(p, glitch_r, Color(CRIMSON, 0.22))
				_stage_fx.draw_arc(p, glitch_r + 4.0, 0.0, TAU, 32, CYAN, 1.8, true)
			if hp < max_hp or is_hov or has_lock_shield or is_boss_core:
				var bw := 48.0 if is_boss_core else 36.0
				var bx := p.x - bw * 0.5
				var by := p.y + rad + 5.0
				_stage_fx.draw_rect(Rect2(bx, by, bw, 5.0), Color(0.05, 0.07, 0.09, 0.92))
				var gh_hp := float(_hp_ghost.get(rid, float(hp)))
				if gh_hp > float(hp):
					_stage_fx.draw_rect(Rect2(bx, by, bw * clampf(gh_hp / float(max_hp), 0.0, 1.0), 5.0), Color(CRIMSON, 0.85))
				_stage_fx.draw_rect(Rect2(bx, by, bw * (float(hp) / float(max_hp)), 5.0), col)
				if has_lock_shield:
					var lx := bx + bw * (float(lock_hp) / float(max_hp))
					_stage_fx.draw_line(Vector2(lx, by - 2.0), Vector2(lx, by + 6.5), GOLD, 2.0)

			if is_hov or can_hit:
				var tag := "%s %d" % [r["name"], hp]
				var tag_col := GOLD if is_hov else Color("#d9f8ff")
				if is_hov:
					var est_dmg := 0
					if active_aim_slot >= 0 and active_aim_slot < _latest.terminal_cards.size():
						est_dmg = _card_damage(_latest.terminal_cards[active_aim_slot].data, hp)
					elif not _drag_active and not _latest.education_turn and core.can_attack_region(rid) and _latest.attack_left > 0:
						var eff_p := 1.0 if (rid == "south_asia" and bool(_latest.get("penicillin_turn", false))) else float(r.get("efficiency", 1.0))
						est_dmg = floori(eff_p * float(_latest.get("conventional_power", 15)))
					if est_dmg > 0:
						if has_lock_shield and (hp - est_dmg <= lock_hp):
							tag += " → 🛡锁血%d!" % lock_hp
							tag_col = CRIMSON
						elif est_dmg >= hp:
							tag += " → 💀一击攻克!"
							tag_col = GOLD
						else:
							tag += " → 约%d" % (hp - est_dmg)
				var tsize := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
				var tpos := p + Vector2(-tsize.x * 0.5, -rad - 8.0)
				_stage_fx.draw_string(font, tpos + Vector2(1, 1), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.95))
				_stage_fx.draw_string(font, tpos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tag_col)

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

	# 4b. 命中爆散火花粒子
	for sp in _sparks:
		var sl := clampf(float(sp["life"]), 0.0, 1.0)
		var sa := 1.0 - sl
		var sr := lerpf(float(sp.get("rad", 3.6)), 0.8, sl)
		var spos: Vector2 = sp["pos"]
		var svel: Vector2 = sp["vel"]
		_stage_fx.draw_line(spos, spos - svel * 0.025, Color(sp["col"], sa * 0.75), maxf(1.2, sr * 0.8), true)
		_stage_fx.draw_circle(spos, sr, Color(sp["col"], sa))

	# 4c. 活物桌面物件悬停微光提示
	if _hovered_prop != "":
		var p_pos := Vector2.ZERO
		var p_hint := ""
		var p_col := GOLD
		if _hovered_prop == "crt":
			p_pos = _uv_to_stage(UV_CRT)
			p_hint = "⚡ 点击终端：快捷刷新 (%d/3)" % int(_latest.get("refreshes_left", 0))
			p_col = CYAN
		elif _hovered_prop == "cauldron":
			p_pos = _uv_to_stage(UV_CAULDRON)
			p_hint = "🔥 点击青铜鼎：拨旺咸阳炉火"
			p_col = GOLD
		elif _hovered_prop == "emperor":
			p_pos = _uv_to_stage(UV_EMPEROR)
			p_hint = "👑 点击始皇：聆听大秦御旨"
			p_col = CRIMSON if (patience <= 3 or low) else GOLD
		elif _hovered_prop.begins_with("advisor_"):
			var ai := int(_hovered_prop.substr(8))
			if ai < UV_ADVISORS.size() and ai < _latest.get("advisors", []).size():
				p_pos = _uv_to_stage(UV_ADVISORS[ai])
				p_hint = "💬 点击【%s】：聆听建言" % _latest["advisors"][ai]["name"]
				p_col = CYAN
		if p_hint != "":
			var pr_rad := 34.0 + 4.0 * sin(_anim_time * 5.0)
			_stage_fx.draw_arc(p_pos, pr_rad, 0.0, TAU, 28, Color(p_col, 0.45), 1.8, true)
			var hsz2 := font.get_string_size(p_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
			var hpos2 := p_pos + Vector2(-hsz2.x * 0.5, -pr_rad - 10.0)
			_stage_fx.draw_string(font, hpos2 + Vector2(1, 1), p_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.95))
			_stage_fx.draw_string(font, hpos2, p_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, p_col)

	# 5. 瞄准或拖拽指向卡动态战术弧线
	if active_aim_slot >= 0 and active_aim_slot < _card_nodes.size():
		var card_n := _card_nodes[active_aim_slot]
		var start_p := (card_n.position + Vector2(card_n.size.x * 0.5, 10.0) - _stage.position) / maxf(0.5, _stage.scale.x)
		var end_p := (get_viewport().get_mouse_position() - _stage.position) / maxf(0.5, _stage.scale.x)
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


func _draw_mini_landmark(p: Vector2, id: String, col: Color) -> void:
	var dark := Color(0.05, 0.05, 0.06, 0.92)
	match id:
		"xianyang":
			# 重檐咸阳宫殿剪影
			_stage_fx.draw_colored_polygon(PackedVector2Array([p + Vector2(-10, 3), p + Vector2(10, 3), p + Vector2(7, -2), p + Vector2(-7, -2)]), dark)
			_stage_fx.draw_colored_polygon(PackedVector2Array([p + Vector2(-12, -2), p + Vector2(12, -2), p + Vector2(0, -10)]), col)
			_stage_fx.draw_line(p + Vector2(-9, 3), p + Vector2(9, 3), col, 1.5)
		"steppe":
			# 匈奴苍狼王帐穹顶剪影
			_stage_fx.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 4), p + Vector2(8, 4), p + Vector2(6, -2), p + Vector2(0, -8), p + Vector2(-6, -2)]), col)
			_stage_fx.draw_line(p + Vector2(0, -8), p + Vector2(0, -12), GOLD, 1.4)
		"west":
			# 玉门关城垛烽火台剪影
			_stage_fx.draw_rect(Rect2(p + Vector2(-8, -4), Vector2(16, 8)), col)
			_stage_fx.draw_rect(Rect2(p + Vector2(-8, -8), Vector2(4, 4)), col)
			_stage_fx.draw_rect(Rect2(p + Vector2(-2, -8), Vector2(4, 4)), col)
			_stage_fx.draw_rect(Rect2(p + Vector2(4, -8), Vector2(4, 4)), col)
		"south_asia":
			# 孔雀王朝大佛塔穹顶剪影
			_stage_fx.draw_circle(p + Vector2(0, 1), 6.5, col)
			_stage_fx.draw_rect(Rect2(p + Vector2(-8, 1), Vector2(16, 4)), col)
			_stage_fx.draw_line(p + Vector2(0, -5), p + Vector2(0, -10), GOLD, 1.6)
		"west_asia":
			# 双金字塔剪影
			_stage_fx.draw_colored_polygon(PackedVector2Array([p + Vector2(-10, 4), p + Vector2(2, 4), p + Vector2(-4, -8)]), col)
			_stage_fx.draw_colored_polygon(PackedVector2Array([p + Vector2(-1, 4), p + Vector2(10, 4), p + Vector2(4.5, -5)]), col.darkened(0.2))
		"europe":
			# 罗马斗兽场与石柱拱门剪影
			_stage_fx.draw_rect(Rect2(p + Vector2(-9, -4), Vector2(18, 8)), col)
			_stage_fx.draw_rect(Rect2(p + Vector2(-6, -1), Vector2(3, 5)), dark)
			_stage_fx.draw_rect(Rect2(p + Vector2(-1.5, -1), Vector2(3, 5)), dark)
			_stage_fx.draw_rect(Rect2(p + Vector2(3, -1), Vector2(3, 5)), dark)
		"americas":
			# 玛雅阶梯金字塔剪影
			_stage_fx.draw_rect(Rect2(p + Vector2(-9, 1), Vector2(18, 4)), col)
			_stage_fx.draw_rect(Rect2(p + Vector2(-6.5, -3), Vector2(13, 4)), col)
			_stage_fx.draw_rect(Rect2(p + Vector2(-4, -7), Vector2(8, 4)), col)
		"paradox_core":
			_stage_fx.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -11), p + Vector2(10, 0), p + Vector2(0, 11), p + Vector2(-10, 0)]), col)
			_stage_fx.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), CYAN)
		_:
			_stage_fx.draw_circle(p, 5.0, col)


func _input(event: InputEvent) -> void:
	if _drag_slot < 0:
		return
	if event is InputEventMouseMotion:
		if not _drag_active and event.position.distance_to(_drag_start_pos) >= 16.0:
			_drag_active = true
			_popover.hide()
			if _drag_slot < _card_nodes.size():
				_card_nodes[_drag_slot].z_index = 40
			_play_sfx("hover")
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var slot := _drag_slot
		var was_drag := _drag_active
		_drag_slot = -1
		_drag_active = false
		if was_drag:
			_finish_card_drag(slot, event.position)
			get_viewport().set_input_as_handled()


func _finish_card_drag(slot: int, drop_pos: Vector2) -> void:
	if slot < 0 or slot >= _latest.get("terminal_cards", []).size():
		_rebuild_hand_cards(false)
		return
	var card: Dictionary = _latest.terminal_cards[slot]
	var vp := get_viewport_rect().size
	if _modal_shade.visible or _title_curtain.visible or card.bought or _latest.actions_left <= 0:
		_rebuild_hand_cards(false)
		return
	var is_targeted: bool = card.kind == "cheat" and bool(card.data.get("needs_target", false))
	if is_targeted:
		var stage_pos := _stage.get_global_transform().affine_inverse() * drop_pos
		for region in _latest.regions:
			var rid: String = region.id
			if region.conquered or not UV_REGIONS.has(rid):
				continue
			var target := _uv_to_stage(UV_REGIONS[rid])
			if target.distance_to(stage_pos) <= (32.0 if rid == "paradox_core" else 26.0):
				_pending_cheat_slot = -1
				_play_sfx("click")
				_spawn_sparks(target, GOLD, 16, 170.0)
				_result(core.buy_cheat(slot, rid))
				return
		_rebuild_hand_cards(false)
	else:
		if drop_pos.y < vp.y * 0.72:
			_spawn_sparks(_uv_to_stage(UV_XIANYANG), GOLD if card.kind == "advisor" else CYAN, 22, 200.0)
			_use_card(slot)
			if _replace_panel.visible:
				_rebuild_hand_cards(false)
		else:
			_rebuild_hand_cards(false)


func _spawn_sparks(stage_pos: Vector2, col: Color, count: int = 16, speed: float = 180.0, grav: float = 220.0) -> void:
	for i in range(count):
		var ang := randf_range(0.0, TAU)
		var spd := randf_range(speed * 0.35, speed * 1.15)
		_sparks.append({
			"pos": stage_pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)),
			"vel": Vector2(cos(ang), sin(ang)) * spd + Vector2(0, -45.0),
			"col": col if randf() > 0.25 else Color.WHITE,
			"life": 0.0,
			"dur": randf_range(0.32, 0.62),
			"rad": randf_range(2.2, 4.4),
			"grav": grav,
		})


func _tabletop_prop_at(stage_pos: Vector2) -> String:
	for ai in range(mini(UV_ADVISORS.size(), _latest.advisors.size())):
		if _uv_to_stage(UV_ADVISORS[ai]).distance_to(stage_pos) <= 64.0:
			return "advisor_%d" % ai
	if _uv_to_stage(UV_CRT).distance_to(stage_pos) <= 68.0:
		return "crt"
	if _uv_to_stage(UV_CAULDRON).distance_to(stage_pos) <= 58.0:
		return "cauldron"
	if _uv_to_stage(UV_EMPEROR).distance_to(stage_pos) <= 62.0:
		return "emperor"
	return ""

func _interact_tabletop_prop(prop: String) -> void:
	if prop == "cauldron":
		_play_sfx("hover")
		var cp := _uv_to_stage(UV_CAULDRON)
		_spawn_sparks(cp + Vector2(0, -16), Color("#ff9c3b"), 28, 190.0, -140.0)
		_pulses.append({"pos": cp, "col": GOLD, "t": 0.0, "max_r": 72.0})
		_screen_flash(Color("#ff9c3b"), 0.14, 0.24)
		_lbl_ticker.text = "🔥 咸阳青铜鼎火光大盛，照彻玄黑沙盘！"
	elif prop == "emperor":
		_play_sfx("event")
		_emperor_glare_timer = 2.6
		_shake_strength = maxf(_shake_strength, 6.5)
		var ep := _uv_to_stage(UV_EMPEROR)
		var urgent := int(_latest.get("patience", 12)) <= 3 or bool(_latest.get("paradox_phase", false))
		_spawn_sparks(ep, CRIMSON if urgent else GOLD, 20, 160.0, 40.0)
		var emp_lines := [
			"「国师，朕给你的十二回合，可不是让你在殿上观火的。」",
			"「六合之内，皇帝之土。何处未染玄黑，便向何处亮剑！」",
			"「善用名臣羁绊，莫让万民离心，亦莫让朕久等。」",
		]
		if bool(_latest.get("paradox_phase", false)):
			emp_lines = ["「2076 终端竟敢反噬大秦？国师，给朕轰碎它！」"]
		elif int(_latest.get("morale", 60)) < 40:
			emp_lines = ["「民心已动摇！速行民生安抚，否则大泽乡之火将焚尽咸阳！」"]
		var pick: String = emp_lines[randi() % emp_lines.size()]
		_spawn_float_text(ep + Vector2(0, 32), "👑 始皇凝视", CRIMSON if urgent else GOLD)
		_lbl_ticker.text = "【秦始皇】%s" % pick
	elif prop == "crt":
		_crt_glitch_timer = 0.45
		var crt_p := _uv_to_stage(UV_CRT)
		_spawn_sparks(crt_p, CYAN, 18, 175.0, 80.0)
		if not _btn_refresh.disabled:
			_play_sfx("click")
			_cancel_aim()
			_result(core.refresh_terminal())
		else:
			_play_sfx("hover")
			_lbl_ticker.text = "⚡ [TERMINAL_2076] 显像管发出滋滋电流声：本回合刷新额度已耗尽。"
	elif prop.begins_with("advisor_"):
		var ai := int(prop.substr(8))
		var advs: Array = _latest.get("advisors", [])
		if ai >= 0 and ai < advs.size():
			var adv: Dictionary = advs[ai]
			_play_sfx("chime")
			var ap := _uv_to_stage(UV_ADVISORS[ai])
			_spawn_sparks(ap, CYAN if ai == 0 else GOLD, 16, 150.0, 60.0)
			if ai < _holo_rects.size():
				var hr := _holo_rects[ai]
				hr.pivot_offset = hr.size * 0.5
				var tw := hr.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(hr, "scale", Vector2(1.16, 0.90), 0.08)
				tw.tween_property(hr, "scale", Vector2(0.95, 1.08), 0.10)
				tw.tween_property(hr, "scale", Vector2.ONE, 0.12)
			var bucket := "low_morale" if int(_latest.get("morale", 60)) < 45 else "normal"
			var line := core._get_advisor_line(adv["id"], bucket)
			_on_advisor_spoke(adv["id"], adv["name"], line)


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
	if _codex_panel.visible and (event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_C)):
		_toggle_codex()
		get_viewport().set_input_as_handled()
		return
	if _hidden_panel.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		_play_sfx("click"); _hidden_panel.hide(); _sync_modal_shade()
		get_viewport().set_input_as_handled()
		return
	if _pact_panel.visible and event.is_action_pressed("ui_cancel"):
		_play_sfx("click"); _pact_panel.hide(); _sync_modal_shade()
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
			KEY_C:
				_toggle_codex()
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
		var stage_m: Vector2 = (event.position - _stage.position) / maxf(0.5, _stage.scale.x)
		var hvis_c: Dictionary = _latest.get("hidden_visible", {})
		for hid in UV_HIDDEN.keys():
			if bool(hvis_c.get(hid, false)) and _uv_to_stage(UV_HIDDEN[hid]).distance_to(stage_m) <= 22.0:
				_play_sfx("click"); _cancel_aim(); _result(core.trigger_hidden(hid))
				get_viewport().set_input_as_handled()
				return
		if _pending_cheat_slot < 0 and _uv_to_stage(UV_XIANYANG).distance_to(stage_m) <= 24.0:
			_play_sfx("click")
			_selected = "xianyang"
			_refresh_popover()
			get_viewport().set_input_as_handled()
			return
		for r_item in _latest.get("regions", []):
			var rid: String = r_item["id"]
			if UV_REGIONS.has(rid) and _uv_to_stage(UV_REGIONS[rid]).distance_to(stage_m) <= (32.0 if rid == "paradox_core" else 26.0):
				_on_region_clicked(rid)
				get_viewport().set_input_as_handled()
				return
		var prop := _tabletop_prop_at(stage_m)
		if prop != "":
			_interact_tabletop_prop(prop)
			get_viewport().set_input_as_handled()
			return
		if _popover.visible and not _popover.get_global_rect().has_point(event.position):
			_selected = ""
			_popover.hide()


func _restart(show_banner: bool = true) -> void:
	_clear_presentations()
	_pending_cheat_slot = -1
	_pending_replace_card_slot = -1
	_selected = ""
	_hovered_region = ""
	_prev_morale = 60
	_prev_patience = 12
	_prev_act = 0
	_last_cards_sig = ""
	_hidden_triggered_count = 0
	_sparks.clear()
	_hp_ghost.clear()
	_hitstop_timer = 0.0
	_emperor_glare_timer = 0.0
	_crt_glitch_timer = 0.0
	_drag_slot = -1
	_drag_active = false
	_used_nuke = false
	_popover.hide()
	_ending_panel.hide()
	_event_panel.hide()
	_replace_panel.hide()
	_rules_panel.hide()
	_log_panel.hide()
	_codex_panel.hide()
	_hidden_panel.hide()
	_debate_panel.hide()
	_pact_panel.hide()
	_modal_shade.hide()
	for i in range(2):
		_bubbles[i].hide()
		_bubble_timers[i] = 0.0
	core.init_game(_game_data, _lines_data, _mvp_only, -1, _tactical_mode)
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
		or _codex_panel.visible
		or _hidden_panel.visible
		or _debate_panel.visible
		or _pact_panel.visible
		or (not _latest.is_empty() and not _latest.get("pending_debate", {}).is_empty())
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
		if old_act > 0 and _prev_act > old_act and not snap.paradox_phase and not _title_curtain.visible:
			_play_sfx("chime")
			_show_act_banner(_prev_act)

	_lbl_act.text = "第 %d 回合 · 第 %d 幕" % [snap["turn"], snap["act"]]
	var low := _prev_morale < 40
	_lbl_morale.text = "%s民心 %d/%d" % ["⚠ " if low else "", _prev_morale, int(snap["morale_cap"])]
	_lbl_morale.modulate = CRIMSON if low else CYAN
	_bar_morale.max_value = int(snap["morale_cap"])
	_bar_morale.value = _prev_morale
	_bar_morale.add_theme_stylebox_override("fill", _flat_style(CRIMSON if low else CYAN, Color.TRANSPARENT, 0, 3))
	if bool(snap.get("paradox_phase", false)):
		var p_hp := 0
		for r_chk in snap["regions"]:
			if r_chk["id"] == "paradox_core":
				p_hp = int(r_chk["hp"])
		_lbl_conquest.text = "⚠ 焚书核心 %d/260" % p_hp
		_lbl_conquest.modulate = CRIMSON
	else:
		_lbl_conquest.text = "统一 %d/6" % int(snap["conquered_count"])
		_lbl_conquest.modulate = Color.WHITE
	_lbl_patience.text = "%s始皇耐心 %d" % ["⚠ " if _prev_patience <= 3 else "", _prev_patience]
	_lbl_patience.modulate = CRIMSON if _prev_patience <= 3 else MUTED
	_crt_status.text = "TERMINAL_2076\n剩余行动点 %d\n剩余常规进攻 %d 次" % [int(snap["actions_left"]), int(snap["attack_left"])]
	_vignette_mat.set_shader_parameter("danger_intensity", 1.0 if (low or bool(snap.get("paradox_phase", false))) else 0.0)

	# 声音作为玩法信息源：第三幕切换紧张战鼓；民心 < 40 时起义喧哗随 (40 - 民心) 线性放大
	if _bgm_player != null and not _audio_muted:
		var want_bgm: AudioStream = _bgm_act3_stream if (_prev_act >= 3 and _bgm_act3_stream != null) else _bgm_ambient_stream
		if want_bgm != null and _bgm_player.stream != want_bgm:
			_bgm_player.stream = want_bgm
			_bgm_player.play()
		_bgm_player.pitch_scale = 1.14 if bool(snap.get("paradox_phase", false)) else 1.0
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
	_threat_label.hide()
	var threat: Dictionary = snap.get("active_threat", {})
	if not threat.is_empty() and not threat.get("interrupted", false) and snap.game_over_code == "":
		for region in snap.regions:
			if region.id == threat.region_id and not region.conquered:
				_threat_label.text = "⚠ %s · 攻打「%s」破招" % [threat.title, region.name]
				_threat_label.show()
				break

	# 更新两位全息名臣立绘及悬停技能提示
	var advs: Array = snap["advisors"]
	var meta_dirty := false
	var sum_list: Array = _meta_save.get("summoned", [])
	for a_rec in advs:
		if not (a_rec["id"] in sum_list):
			sum_list.append(a_rec["id"])
			meta_dirty = true
	if int(snap.get("turn", 1)) >= 2 and not bool(_meta_save.get("tutorial_done", false)):
		_meta_save["tutorial_done"] = true
		meta_dirty = true
	if meta_dirty:
		_meta_save["summoned"] = sum_list
		_save_meta_save()
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

	_update_first_turn_guide(snap)
	if bool(snap.get("free_hook_available", false)):
		_lbl_ticker.text = "★ 首回合高光：下方首次召唤【名臣】或拍出【无人机蜂群】免民心；点击沙盘发光点可直接出兵。"
	elif _lbl_ticker.text == "":
		_lbl_ticker.text = "点击沙盘发光点查看守军并出兵，按 1/2/3 快捷键可快速抬牌。"

	var new_sig := _cards_signature(snap["terminal_cards"])
	var should_deal := (new_sig != _last_cards_sig) and not _title_curtain.visible
	_last_cards_sig = new_sig
	_rebuild_hand_cards(should_deal)
	_refresh_popover()


func _update_first_turn_guide(snap: Dictionary) -> void:
	if _guide_bar == null:
		return
	if bool(_meta_save.get("tutorial_done", false)) or _title_curtain.visible or int(snap.get("turn", 1)) > 1:
		_guide_bar.visible = false
		return
	if bool(snap.get("free_hook_available", false)):
		_guide_lbl.text = "💡 新手引导 1/3：召唤一位免费名臣，或把无人机拖到敌方战区。"
		_guide_bar.visible = true
	elif int(snap.get("attack_left", 0)) > 0:
		_guide_lbl.text = "💡 新手引导 2/3：点击地图上的敌方战区，再点「常规进攻」。"
		_guide_bar.visible = true
	else:
		_guide_lbl.text = "💡 新手引导 3/3：点击右下角【结束本回合】，进入下一回合。"
		_guide_bar.visible = true


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
	var dec: Dictionary = snap.get("active_decree", {})
	if not dec.is_empty():
		if bool(dec.get("done", false)):
			items.append(["✔ %s已成" % dec["title"], SAGE, dec["reward"]])
		else:
			items.append(["📜 %s：%s" % [dec["title"], dec["goal"]], GOLD, "赏赐：" + dec["reward"]])
	for syn in snap.get("active_synergies", []):
		items.append(["✦ 羁绊·%s" % syn["name"], GOLD, syn["desc"]])
	if int(snap.get("debate_next_mil_bonus", 0)) > 0:
		items.append(["⚔ 铁血之议 +%d伤" % int(snap["debate_next_mil_bonus"]), CRIMSON, "本回合下张军事外挂附加伤害"])
	if bool(snap.get("secret_overclock_active", false)):
		items.append(["⚡ 乾坤借势 ×2伤害", GOLD, "本回合下次进攻或军事外挂伤害翻倍"])
	if bool(snap.get("pact_free_hand_turn", false)):
		items.append(["🔥 焚鼎献祭·全牌0费", CRIMSON, "本回合所有手牌免民心消耗"])
	for it in items:
		var pill := PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_STOP if it.size() >= 3 else Control.MOUSE_FILTER_IGNORE
		if it.size() >= 3:
			pill.tooltip_text = str(it[2])
		pill.add_theme_stylebox_override("panel", _flat_style(Color(0.04, 0.055, 0.07, 0.86), Color(it[1], 0.8), 5, 5))
		_buffs_box.add_child(pill)
		var lbl := _label(pill, it[0], 11, it[1])
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _rebuild_hand_cards(animate_deal: bool = false) -> void:
	_drag_active = false
	_drag_slot = -1
	for n in _card_nodes:
		n.queue_free()
	_card_nodes.clear()
	_card_base_pos.clear()

	_btn_cancel_aim.visible = _pending_cheat_slot >= 0
	_btn_refresh.text = "刷新终端 %d/3 (−%d)" % [_latest.refreshes_left, core.get_refresh_cost()]
	_btn_refresh.disabled = _latest.refreshes_left <= 0 or _latest.overheat_no_refresh
	_btn_fleet.text = "渡海航线已通" if _latest.sea_unlocked else "强征造楼船 (−%d)" % core.get_fleet_cost()
	_btn_fleet.disabled = _latest.sea_unlocked or _latest.actions_left <= 0
	var pact_done: bool = bool(_latest.get("pact_used", false))
	_btn_pact.text = "🔥 密匣已启" if pact_done else "🔥 始皇密匣（逆天改命）"
	_btn_pact.disabled = pact_done
	for ch in _secret_box.get_children():
		ch.queue_free()
	var scards: Array = _latest.get("secret_cards", [])
	for si in range(scards.size()):
		var sc: Dictionary = scards[si]
		var sc_name: String = sc["name"]
		var sc_desc: String = sc["desc"]
		var sb := _button(_secret_box, "★ 0费秘技 · %s" % sc_name, func():
			_play_sfx("chime")
			_cancel_aim()
			var res := core.cast_secret_card(si)
			if res.get("ok", false):
				_show_cutin("★ 国师秘技 · %s" % sc_name, sc_desc, GOLD)
			_result(res)
		, GOLD)
		sb.add_theme_stylebox_override("normal", _flat_style(Color(0.16, 0.11, 0.04, 0.94), GOLD, 8, 6))
		sb.add_theme_color_override("font_color", GOLD)
		sb.tooltip_text = sc["desc"]

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
	var card_sz := Vector2(186.0, 226.0)
	var gap := 16.0
	var count := _card_nodes.size()
	var total_w := float(count) * card_sz.x + float(count - 1) * gap
	var start_x := (vp.x - total_w) * 0.5 - 24.0
	var base_y := vp.y - card_sz.y + 6.0
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
	var is_corrupted: bool = (not card.bought) and bool(_latest.get("paradox_phase", false)) and (slot == int(_latest.get("corrupted_slot", -1)))
	if is_corrupted:
		delta -= 10
	var badge := "★ 免费" if (is_free and not is_corrupted) else ("已部署" if card.bought else (("⚠ 污染 %+d" % delta) if is_corrupted else ("%+d" % delta if delta != 0 else "免耗")))
	var disabled: bool = card.bought or _latest.actions_left <= 0 or (data.id == "education" and _latest.attack_left <= 0)
	var active: bool = (slot == _pending_cheat_slot)

	var root := Control.new()
	root.custom_minimum_size = Vector2(186, 226)

	var frame := TextureRect.new()
	frame.texture = _tex_card
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate = Color(1.25, 0.52, 0.52, 1.0) if is_corrupted else (Color(1.18, 1.12, 1.0, 1.0) if (active or is_free) else (Color(0.55, 0.55, 0.58, 0.72) if disabled else Color.WHITE))
	root.add_child(frame)

	var rim := ColorRect.new()
	rim.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rim.offset_left = 18; rim.offset_top = 12; rim.offset_right = -18; rim.offset_bottom = 15
	rim.color = CRIMSON if is_corrupted else (GOLD if is_free else tint)
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
	if advisor and ResourceLoader.exists(data.get("portrait", "")):
		art_tex = load(data["portrait"])
	elif not advisor and ResourceLoader.exists(data.get("art", "")):
		art_tex = load(data["art"])
	elif not advisor and _category_icons.has(data.category):
		art_tex = _category_icons[data.category]
	if art_tex != null:
		var pframe := PanelContainer.new()
		pframe.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pframe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pframe.add_theme_stylebox_override("panel", _flat_style(Color(0.03, 0.04, 0.05, 0.9), Color(tint, 0.7), 2, 4))
		body.add_child(pframe)
		var pr := TextureRect.new()
		pr.texture = art_tex
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pr.custom_minimum_size = Vector2(66, 66)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pframe.add_child(pr)

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
	hit.button_down.connect(func():
		if not disabled and not _modal_shade.visible and not _title_curtain.visible:
			_drag_slot = slot
			_drag_start_pos = get_viewport().get_mouse_position()
			_drag_active = false
	)
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
	if _selected == "xianyang":
		_popover.show()
		_pop_img.texture = _landmarks.get("xianyang", null)
		_pop_title.text = "大秦 · 咸阳本土"
		_pop_badge.text = "◆ 帝国龙兴之地 · 玄黑本营"
		_pop_badge.modulate = GOLD
		_pop_sub.text = "咸阳宫与万里长城 · 常规秦军战力 %d" % int(_latest.conventional_power)
		_pop_bar.max_value = int(_latest.morale_cap)
		_pop_bar.value = int(_latest.morale)
		_pop_bar.add_theme_stylebox_override("fill", _flat_style(GOLD, Color.TRANSPARENT, 0, 3))
		var adv_list := []
		for a in _latest.get("advisors", []):
			adv_list.append(a["name"])
		_pop_desc.text = "在场名臣：%s\n渡海航线：%s · 已统一 %d/6 大洲" % [
			"、".join(adv_list) if not adv_list.is_empty() else "暂无（可从下方手牌召唤）",
			"已打通" if bool(_latest.sea_unlocked) else "未开通",
			int(_latest.conquered_count)
		]
		_pop_attack.hide()
		return

	for r in _latest.regions:
		if r["id"] != _selected:
			continue
		_popover.show()
		var ltex: Texture2D = _landmarks.get(r["id"], null)
		if ltex == null and r.has("landmark") and ResourceLoader.exists(str(r["landmark"])):
			ltex = load(str(r["landmark"]))
		_pop_img.texture = ltex if ltex != null else _landmarks.get("xianyang", null)
		var lm_name: String = str(r.get("landmark_name", r["coverage"]))
		_pop_title.text = "%s · %s" % [r["name"], "已归玄黑" if r["conquered"] else "守军 %d/%d" % [int(r["hp"]), int(r["max_hp"])]]
		_pop_bar.max_value = int(r["max_hp"])
		_pop_bar.value = int(r["max_hp"]) if r["conquered"] else int(r["hp"])
		_pop_bar.add_theme_stylebox_override("fill", _flat_style(GOLD if r["conquered"] else CYAN, Color.TRANSPARENT, 0, 3))
		if r["conquered"]:
			_pop_badge.text = "◆ 大秦郡县已设 · 归入玄黑"
			_pop_badge.modulate = GOLD
			_pop_sub.text = "%s（%s）" % [lm_name, r["coverage"]]
			_pop_desc.text = r["reward"]
			_pop_attack.hide()
		else:
			var ready := core.can_attack_region(r["id"])
			var eff := 1.0 if r["id"] == "south_asia" and _latest.penicillin_turn else float(r["efficiency"])
			var dmg := floori(eff * _latest.conventional_power)
			_pop_badge.text = "⚔ 敌境实景侦查 · 常规效率 %d%%" % int(round(eff * 100.0))
			_pop_badge.modulate = CYAN
			var wk := core.get_region_weakness_info(r["id"])
			var thr2: Dictionary = _latest.get("active_threat", {})
			var thr_note := ""
			if not thr2.is_empty() and not bool(thr2.get("interrupted", false)) and thr2.get("region_id", "") == r["id"]:
				thr_note = "\n⚠ 敌军意图【%s】：%s（攻击即破招+5民心）" % [thr2["title"], thr2["desc"]]
			var lock_note := ""
			var l_hp := int(r.get("boss_lock_hp", 0))
			if l_hp > 0 and not bool(r.get("phase2_triggered", false)):
				lock_note = "\n🛡 锁血二阶段：HP 降至 %d 触发反扑（抵消溢出伤害）" % l_hp
			_pop_sub.text = "%s\n🎯 %s%s%s" % [lm_name, wk["label"], lock_note, thr_note]
			_pop_attack.show()
			_pop_attack.text = "⚔ 常规进攻 (−%d 战力)" % dmg
			_pop_attack.disabled = not ready or _latest.attack_left <= 0 or _latest.education_turn
			if not ready:
				_pop_desc.text = "需先开通渡海航线（造楼船或跨海铁甲舰）。" if r["requires_sea"] else "需先攻克前置板块。"
			elif _latest.education_turn:
				_pop_desc.text = "本回合已推行义务教育，无法常规进攻。"
			elif _latest.attack_left <= 0:
				_pop_desc.text = "本回合常规进攻已用完，下一回合恢复。"
			else:
				_pop_desc.text = "%s（再次点击据点也可直接出兵）" % r["reward"]


func _spawn_float_text(stage_pos: Vector2, text: String, col: Color, big: bool = false) -> void:
	var fsize := 28 if big else 22
	var lbl := _label(_stage, text, fsize, col)
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04, 0.96))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position = stage_pos + Vector2(-48.0 + randf_range(-16.0, 16.0), -32.0)
	lbl.scale = Vector2(0.42, 0.42)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.32, 1.32) if big else Vector2(1.18, 1.18), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y - (56.0 if big else 44.0), 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.32)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.28)
	tw.tween_callback(lbl.queue_free)


func _result(res: Dictionary) -> void:
	if not res.get("ok", false):
		_lbl_ticker.text = "⚠ " + str(res.get("error", "操作未完成"))


func _on_strike_performed(region_id: String, damage: int, source: String, conquered: bool) -> void:
	var is_nuke := damage >= 500 or source.find("玉玺") >= 0
	if is_nuke:
		_used_nuke = true
	_play_sfx("conquer" if conquered else "strike")
	_shake_strength = 24.0 if is_nuke else (13.0 if conquered else 6.5)
	if is_nuke:
		_hitstop_timer = 0.075
		_screen_flash(GOLD, 0.60, 0.48)
	elif conquered:
		_hitstop_timer = 0.055
		_screen_flash(GOLD, 0.26, 0.30)
	if UV_REGIONS.has(region_id):
		var target := _uv_to_stage(UV_REGIONS[region_id])
		_projectiles.append({"start": _uv_to_stage(UV_XIANYANG), "end": target, "col": GOLD if (conquered or is_nuke) else CYAN, "t": 0.0, "big": conquered or is_nuke, "triple": is_nuke})
		var region: Dictionary = _latest.regions.filter(func(r): return r.id == region_id)[0]
		var loss := mini(damage, int(region.hp))
		_spawn_float_text(target, "−%d%s" % [loss, " ★攻克!" if conquered else ""], GOLD if (conquered or is_nuke) else CYAN, conquered or is_nuke or loss >= 45)
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
	_screen_flash(CYAN, 0.28, 0.38)
	_pulses.append({"pos": _uv_to_stage(UV_XIANYANG), "col": GOLD, "t": 0.0, "max_r": 74.0})
	_popover.hide()
	var h_info: Dictionary = {}
	for h in _game_data.get("hidden_levels", []):
		if h["id"] == hidden_id:
			h_info = h
			break
	var h_art: String = h_info.get("art", "")
	if h_art != "" and ResourceLoader.exists(h_art):
		_hidden_img.texture = load(h_art)
	_hidden_title.text = str(h_info.get("name", hidden_id))
	_hidden_desc.text = str(h_info.get("story", "你在沙盘边缘发掘出一处尘封的跨时空秘境。"))
	_hidden_reward.text = "✦ 秘境收获：%s" % reward_text
	_hidden_panel.show()
	_sync_modal_shade()
	_lbl_ticker.text = "✦ 隐藏关【%s】：%s" % [_hidden_title.text, reward_text]


func _on_event_triggered(ev: Dictionary) -> void:
	_play_sfx("event")
	_popover.hide()
	var e_art: String = ev.get("art", "")
	if e_art != "" and ResourceLoader.exists(e_art):
		_event_img.texture = load(e_art)
	_event_title.text = ev["title"]
	_event_desc.text = ev["desc"]
	_event_btn_a.text = "A. %s" % ev["option_a"]["label"]
	_event_btn_b.text = "B. %s" % ev["option_b"]["label"]
	_event_panel.show()
	_sync_modal_shade()


func _on_game_ended(code: String, data: Dictionary) -> void:
	_clear_presentations()
	# GameCore emits game_ended before the last state_changed notification.
	var final_state := core.get_snapshot()
	var final_morale := int(final_state.morale)
	var final_turn := int(final_state.turn)
	var won := code.begins_with("win_")
	var is_sage := (code == "win_sage")
	_play_sfx("victory" if is_sage else "defeat")
	_screen_flash(GOLD if is_sage else CRIMSON, 0.42, 0.5)
	_selected = ""
	_popover.hide()
	if code == "win_sage":
		_ending_cg.texture = _tex_end_win
	elif code == "win_tyrant":
		_ending_cg.texture = _tex_end_tyrant
	else:
		_ending_cg.texture = _tex_end_lose

	var grade := "C · 历史回响"
	var broke_paradox: bool = bool(final_state.get("paradox_defeated", false))
	if code == "win_sage" and broke_paradox:
		grade = "S+ · 破壁万世"
	elif code == "win_sage" and final_morale >= 80:
		grade = "S · 盛世千古"
	elif code == "win_sage":
		grade = "A · 守望大同"
	elif code == "win_tyrant":
		grade = "B · 赛博霸业"

	var adv_names := []
	for a in final_state.advisors:
		adv_names.append(a["name"])
	var roster := "、".join(adv_names) if not adv_names.is_empty() else "孤身推演"

	_ending_grade.text = "评级 %s" % grade
	_ending_title.text = "%s" % data.get("title", "终局")
	_ending_desc.text = "%s" % data.get("prompt", "")
	_ending_stats.text = "本局战报：历时 %d 回合 · 统一 %d/6 洲 · 终局民心 %d · 隐藏探索 %d 次\n在场名臣：%s" % [
		final_turn,
		int(final_state.conquered_count),
		final_morale,
		_hidden_triggered_count,
		roster,
	]
	var achs := []
	if code == "win_sage" and final_morale >= 80:
		achs.append("🏆 万民归心")
	if won and final_turn <= 8:
		achs.append("⚡ 闪电一统")
	if _hidden_triggered_count >= 1:
		achs.append("🔍 守望秘境")
	if won and core.has_advisor("tanghe"):
		achs.append("🏯 筑城守望(汤和)")
	if _used_nuke:
		achs.append("☢ 核平天下")
	if won and broke_paradox:
		achs.append("⚡ 破壁国师(击碎2076焚书协议)")
	if won and adv_names.size() >= 2:
		achs.append("👑 不朽双壁")
	_ending_ach.text = "本局解锁勋章：" + ("  ".join(achs) if not achs.is_empty() else "尚无勋章（下次试试触发隐藏关或带名臣通关！）")
	_meta_save["runs"] = int(_meta_save.get("runs", 0)) + 1
	if won:
		_meta_save["wins"] = int(_meta_save.get("wins", 0)) + 1
	var end_list: Array = _meta_save.get("endings", [])
	if not (code in end_list):
		end_list.append(code)
	if won and broke_paradox and not ("paradox_cleared" in end_list):
		end_list.append("paradox_cleared")
	_meta_save["endings"] = end_list
	var rank_order := {"": 0, "C · 历史回响": 1, "B · 赛博霸业": 2, "A · 守望大同": 3, "S · 盛世千古": 4, "S+ · 破壁万世": 5}
	if int(rank_order.get(grade, 0)) > int(rank_order.get(str(_meta_save.get("best_grade", "")), 0)):
		_meta_save["best_grade"] = grade
	_save_meta_save()
	_ending_panel.show()
	_sync_modal_shade()


func _on_threat_interrupted(region_id: String, reward_text: String) -> void:
	_play_sfx("chime")
	_screen_flash(GOLD, 0.24, 0.3)
	if UV_REGIONS.has(region_id):
		_spawn_float_text(_uv_to_stage(UV_REGIONS[region_id]) + Vector2(0, -32), "⚡ 破招打断! +5民心", GOLD)
	_lbl_ticker.text = "⚡ %s" % reward_text


func _on_synergy_activated(synergy_name: String, desc: String) -> void:
	_play_sfx("chime")
	_screen_flash(GOLD, 0.32, 0.38)
	_show_cutin("✦ 名臣羁绊共鸣 · %s" % synergy_name, desc, GOLD)


func _show_cutin(title: String, sub: String, accent: Color) -> void:
	if _cutin_bar == null:
		return
	var advs: Array = core.advisors
	_cutin_pic_l.visible = advs.size() >= 1
	_cutin_pic_r.visible = advs.size() >= 2
	if advs.size() >= 1 and ResourceLoader.exists(advs[0].get("portrait", "")):
		_cutin_pic_l.texture = load(advs[0]["portrait"])
	if advs.size() >= 2 and ResourceLoader.exists(advs[1].get("portrait", "")):
		_cutin_pic_r.texture = load(advs[1]["portrait"])
	_cutin_title.text = title
	_cutin_title.modulate = accent
	_cutin_sub.text = sub
	_cutin_bar.add_theme_stylebox_override("panel", _flat_style(Color(0.03, 0.04, 0.06, 0.95), accent, 12, 10))
	_cutin_bar.visible = true
	_cutin_bar.modulate.a = 0.0
	_cutin_bar.scale = Vector2(1.18, 0.82)
	_cutin_bar.pivot_offset = _cutin_bar.size * 0.5
	if _cutin_tween:
		_cutin_tween.kill()
	_cutin_tween = _cutin_bar.create_tween()
	var tw := _cutin_tween
	tw.tween_property(_cutin_bar, "modulate:a", 1.0, 0.14)
	tw.parallel().tween_property(_cutin_bar, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.65)
	tw.tween_property(_cutin_bar, "modulate:a", 0.0, 0.28)
	tw.parallel().tween_property(_cutin_bar, "scale", Vector2(0.92, 0.92), 0.28)
	tw.tween_callback(_cutin_bar.hide)


func _load_meta_save() -> void:
	var path := "user://save.json"
	if not FileAccess.file_exists(path):
		return
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		for k in parsed.keys():
			_meta_save[k] = parsed[k]


func _save_meta_save() -> void:
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_meta_save, "	"))
		f.close()


func _on_decree_completed(title: String, reward_text: String) -> void:
	_play_sfx("victory")
	_screen_flash(GOLD, 0.3, 0.38)
	_lbl_ticker.text = "👑 完成始皇【%s】！赏赐：%s" % [title, reward_text]


func _on_weakness_hit(region_id: String, bonus_text: String) -> void:
	if UV_REGIONS.has(region_id):
		_spawn_float_text(_uv_to_stage(UV_REGIONS[region_id]) + Vector2(0, -56), "⚡ 弱点暴击 %s" % bonus_text, GOLD)


func _on_boss_phase_triggered(region_id: String, title: String, desc: String) -> void:
	_play_sfx("event")
	_screen_flash(CRIMSON, 0.42, 0.45)
	_hitstop_timer = 0.07
	_shake_strength = maxf(_shake_strength, 16.0)
	if UV_REGIONS.has(region_id):
		_spawn_sparks(_uv_to_stage(UV_REGIONS[region_id]), CRIMSON, 32, 260.0)
	if UV_REGIONS.has(region_id):
		_spawn_float_text(_uv_to_stage(UV_REGIONS[region_id]) + Vector2(0, -48), "⚠ 锁血二阶段 · %s" % title, CRIMSON)
	var tw := _start_banner_animation()
	_act_banner_title.text = "⚠ 锁血二阶段 · %s" % title
	_act_banner_sub.text = desc
	_act_banner.visible = true
	_act_banner.modulate.a = 0.0
	tw.tween_property(_act_banner, "modulate:a", 1.0, 0.22)
	tw.tween_interval(2.6)
	tw.tween_property(_act_banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_act_banner.hide)
	_lbl_ticker.text = "⚠ 【%s】%s" % [title, desc]


func _on_paradox_awakened(info: Dictionary) -> void:
	# 第一拍：伪造金色「六洲已定 · 万世太平」胜利横幅（1.35秒）
	_play_sfx("victory")
	_screen_flash(GOLD, 0.45, 0.45)
	var tw := _start_banner_animation()
	_act_banner.add_theme_stylebox_override("panel", _flat_style(Color(0.08, 0.06, 0.02, 0.95), GOLD, 10, 6))
	_act_banner_title.modulate = GOLD
	_act_banner_title.text = "👑 六洲已定 · 大秦万世太平"
	_act_banner_sub.text = "恭喜国师！六大洲尽归玄黑，史官正在篆刻终局盛世档案……"
	_act_banner.visible = true
	_act_banner.modulate.a = 0.0
	tw.tween_property(_act_banner, "modulate:a", 1.0, 0.22)
	tw.tween_interval(1.15)
	# 第二拍：画面乱码撕裂、红闪剧震、始皇猩红双瞳苏醒！
	tw.tween_callback(func():
		_play_sfx("event")
		_hitstop_timer = 0.09
		_emperor_glare_timer = 5.0
		_crt_glitch_timer = 2.4
		_shake_strength = 28.0
		_screen_flash(CRIMSON, 0.72, 0.65)
		_spawn_sparks(_uv_to_stage(UV_REGIONS["paradox_core"]), CRIMSON, 48, 320.0, 80.0)
		_spawn_sparks(_uv_to_stage(UV_CRT), CYAN, 30, 240.0, 60.0)
		_act_banner.add_theme_stylebox_override("panel", _flat_style(Color(0.14, 0.02, 0.03, 0.96), CRIMSON, 10, 6))
		_act_banner_title.modulate = CRIMSON
		_act_banner_title.text = "█▓▒░ ERR_2076 :: 历史修正率 100% ░▒▓█"
		_act_banner_sub.text = "检测到非法时空干涉——伪装终局已终止，强制启动【2076 焚书协议】！"
	)
	tw.tween_interval(1.15)
	# 第三拍：锁定清晰战术简报，正式进入终幕 Boss 决战
	tw.tween_callback(func():
		_act_banner_title.text = "⚠ 终幕 · 2076 焚书协议"
		_act_banner_sub.text = "未来终端核心(260血·130锁血)现身沙盘中央！刷新可净化红色污染牌，击毁核心方能真通关！"
	)
	tw.tween_interval(3.4)
	tw.tween_property(_act_banner, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func():
		_act_banner.hide()
		_act_banner.add_theme_stylebox_override("panel", _flat_style(Color(0.03, 0.04, 0.055, 0.9), GOLD, 10, 6))
		_act_banner_title.modulate = GOLD
	)
	_lbl_ticker.text = "⚠ 【终幕·2076焚书协议】击毁中央终端核心(260血)！刷新终端可净化红色污染手牌，本回合攻击核心可使反噬减半！"


func _on_debate_triggered(debate: Dictionary) -> void:
	_play_sfx("event")
	_popover.hide()
	var a0: Dictionary = debate["advisor_a"]
	var a1: Dictionary = debate["advisor_b"]
	if ResourceLoader.exists(a0.get("portrait", "")):
		_debate_pic_a.texture = load(a0["portrait"])
	if ResourceLoader.exists(a1.get("portrait", "")):
		_debate_pic_b.texture = load(a1["portrait"])
	_debate_name_a.text = "【%s】" % a0["name"]
	_debate_name_b.text = "【%s】" % a1["name"]
	_debate_quote_a.text = "「%s」" % debate["option_a"]["quote"]
	_debate_quote_b.text = "「%s」" % debate["option_b"]["quote"]
	_debate_btn_a.text = "A. %s" % debate["option_a"]["label"]
	_debate_btn_b.text = "B. %s" % debate["option_b"]["label"]
	_debate_panel.show()
	_sync_modal_shade()


func _open_pact_modal() -> void:
	if _modal_shade.visible or _title_curtain.visible or bool(_latest.get("pact_used", false)):
		return
	_play_sfx("event")
	_popover.hide()
	var advs: Array = _latest.get("advisors", [])
	if not advs.is_empty():
		_pact_btn_a.text = "A. 焚鼎献祭：牺牲【%s】→ 本回合全部手牌 0 民心消耗，且行动 +1" % advs[0]["name"]
	else:
		_pact_btn_a.text = "A. 焚鼎献祭：献祭 20 民心 → 本回合全部手牌 0 民心消耗，且行动 +1"
	_pact_panel.show()
	_sync_modal_shade()


func _on_secret_card_gained(card: Dictionary) -> void:
	_play_sfx("victory")
	_screen_flash(GOLD, 0.34, 0.4)
	var tw := _start_banner_animation()
	_act_banner_title.text = "★ 天降 0 费国师秘技 · %s" % card["name"]
	_act_banner_sub.text = card["desc"]
	_act_banner.visible = true
	_act_banner.modulate.a = 0.0
	tw.tween_property(_act_banner, "modulate:a", 1.0, 0.28)
	tw.tween_interval(2.2)
	tw.tween_property(_act_banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_act_banner.hide)


func _on_pact_made(title: String, desc: String) -> void:
	_screen_flash(CRIMSON, 0.42, 0.45)
	_shake_strength = 12.0
	_lbl_ticker.text = "🔥 始皇密匣【%s】：%s" % [title, desc]
