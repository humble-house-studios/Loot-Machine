extends Control
## Loot Machine: a slot-machine roguelite in the office.
## Pull the lever, match symbols from every game in the room, hit each
## quarter's quota before your spins run out. Get promoted after the Annual
## Review and keep an office relic that powers up the other games.
## Layout: upright = machine on top, controls below; sideways = side by side.

const COLOR_BG := Color("#120c0c")
const COLOR_PANEL := Color("#1e1415")
const COLOR_INK := Color("#f4efe4")
const COLOR_DIM := Color(0.96, 0.94, 0.89, 0.55)
const COLOR_GOLD := Color("#ffcf3f")
const COLOR_RED := Color("#ff3b30")
const COLOR_GREEN := Color("#7ee081")
const COLOR_PINK := Color("#ff8fb8")
const SFX := ["lever", "stop", "coin", "bigwin", "layoff", "buy", "click", "fired", "promoted", "relic"]

const MachineView := preload("res://scenes/machine_view.gd")
const PaytableView := preload("res://scenes/paytable_view.gd")
var _font: Font = preload("res://fonts/press_start_2p.ttf")

var _relics: OfficeRelics
var _run: LootRun
## Shards from this run already put in the bank.
var _banked := 0
var _busy := false
var _result := {}
var _shown_coins := 0.0
var _sfx := {}

var _safe: MarginContainer
var _body: BoxContainer
var _machine: MachineView
var _panel: VBoxContainer
var _quarter_label: Label
var _quota_label: Label
var _coins_label: Label
var _spins_label: Label
var _perks_label: Label
var _paytable: PaytableView
var _wallet_label: Label
var _spin_button: Button
var _token_button: Button
var _overlay: Control
var _overlay_box: VBoxContainer


func _ready() -> void:
	_relics = OfficeRelics.open()
	for id in SFX:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://audio/%s.wav" % id)
		add_child(p)
		_sfx[id] = p
	_build_ui()
	# Controller / arrow keys: a frame that moves between buttons, A presses.
	add_child(preload("res://scenes/loot_pad.gd").new())
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	_show_title()


# ---------------------------------------------------------------- layout

func _owns_window() -> bool:
	return get_viewport() == get_window()


func is_landscape() -> bool:
	var s := get_viewport_rect().size
	return s.x > s.y


func _on_resized() -> void:
	var landscape := is_landscape()
	var base := Vector2i(1280, 720) if landscape else Vector2i(720, 1280)
	if _owns_window() and get_window().content_scale_size != base:
		get_window().content_scale_size = base
	_body.vertical = not landscape
	_machine.size_flags_stretch_ratio = 1.6 if landscape else 1.25
	_panel.size_flags_stretch_ratio = 1.0
	var m := 24
	var top := m
	if OS.has_feature("mobile") and _owns_window():
		# Keep clear of the notch: the safe area is in screen pixels.
		var safe := DisplayServer.get_display_safe_area()
		var scale := get_viewport_rect().size.y / maxf(1.0, DisplayServer.window_get_size().y)
		top = maxi(m, int(safe.position.y * scale))
	_safe.add_theme_constant_override("margin_top", top)
	for side in ["margin_left", "margin_right", "margin_bottom"]:
		_safe.add_theme_constant_override(side, m)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.material = ShaderMaterial.new()
	bg.material.shader = preload("res://scenes/backdrop.gdshader")
	add_child(bg)

	_safe = MarginContainer.new()
	_safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_safe)
	_body = BoxContainer.new()
	_body.add_theme_constant_override("separation", 18)
	_safe.add_child(_body)

	_machine = MachineView.new()
	_machine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_machine.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_machine.custom_minimum_size = Vector2(320, 280)
	_machine.pulled.connect(_on_spin)
	_machine.reel_stopped.connect(func(_c): _play("stop", randf_range(0.9, 1.1)))
	_body.add_child(_machine)

	_panel = VBoxContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_theme_constant_override("separation", 10)
	_body.add_child(_panel)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	_panel.add_child(stats)
	_quarter_label = _label("", 20, COLOR_GOLD)
	_quarter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(_quarter_label)
	_spins_label = _label("", 20, COLOR_INK)
	_spins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_child(_spins_label)

	_coins_label = _label("", 44, COLOR_GOLD)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_coins_label)
	_quota_label = _label("", 18, COLOR_DIM)
	_quota_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_quota_label)

	_perks_label = _label("", 16, COLOR_PINK)
	_perks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_perks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_perks_label)

	_paytable = PaytableView.new()
	_paytable.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_paytable.custom_minimum_size.y = 60
	_panel.add_child(_paytable)

	_wallet_label = _label("", 16, COLOR_DIM)
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_wallet_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	_panel.add_child(buttons)
	_token_button = _button("TOKEN\nSPIN", Color("#4cc9f0"), 20)
	_token_button.custom_minimum_size = Vector2(200, 110)
	_token_button.pressed.connect(_on_token_spin)
	_token_button.set_meta("pad_button", JOY_BUTTON_Y)
	buttons.add_child(_token_button)
	_spin_button = _button("PULL", COLOR_RED, 40)
	_spin_button.custom_minimum_size = Vector2(0, 110)
	_spin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spin_button.pressed.connect(_on_spin)
	_spin_button.set_meta("pad_button", JOY_BUTTON_X)
	_spin_button.set_meta("pad_default", true)
	buttons.add_child(_spin_button)

	_overlay = ColorRect.new()
	_overlay.color = Color(0.03, 0.02, 0.02, 0.9)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_overlay.add_child(scroll)
	var center := MarginContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		center.add_theme_constant_override(side, 36)
	scroll.add_child(center)
	_overlay_box = VBoxContainer.new()
	_overlay_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overlay_box.add_theme_constant_override("separation", 18)
	center.add_child(_overlay_box)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_constant_override("line_spacing", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, color: Color, font_size := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 96)
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", COLOR_INK)
	b.add_theme_color_override("font_hover_color", COLOR_INK)
	b.add_theme_color_override("font_pressed_color", COLOR_INK)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 6)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color.darkened(0.45)
	normal.border_color = color
	normal.set_border_width_all(5)
	normal.shadow_color = Color(0, 0, 0, 0.6)
	normal.shadow_offset = Vector2(0, 6)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("focus", normal)
	var down := normal.duplicate()
	down.bg_color = color.darkened(0.15)
	down.shadow_offset = Vector2(0, 1)
	b.add_theme_stylebox_override("pressed", down)
	var off := normal.duplicate()
	off.bg_color = Color(0.12, 0.1, 0.1)
	off.border_color = Color(0.3, 0.27, 0.27)
	b.add_theme_stylebox_override("disabled", off)
	b.pressed.connect(_play.bind("click"))
	return b


func _play(id: String, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = _sfx.get(id)
	if p:
		p.pitch_scale = pitch
		p.play()


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	if _run == null:
		return
	if _shown_coins != _run.coins:
		var gap := _run.coins - _shown_coins
		_shown_coins = move_toward(_shown_coins, _run.coins, maxf(8.0, absf(gap) * 5.0) * delta)
		_coins_label.text = "$%d" % int(round(_shown_coins))


func _refresh() -> void:
	if _run == null:
		return
	var review := _run.is_review()
	_quarter_label.text = "ANNUAL REVIEW" if review else "QUARTER %d" % (_run.quarter + 1)
	_quarter_label.add_theme_color_override("font_color", COLOR_PINK if review else COLOR_GOLD)
	_spins_label.text = "%d SPIN%s" % [_run.spins_left, "" if _run.spins_left == 1 else "S"]
	_spins_label.add_theme_color_override("font_color", COLOR_RED if _run.spins_left <= 2 else COLOR_INK)
	var met := _run.coins >= _run.quota()
	_quota_label.text = ("QUOTA $%d  MET!" if met else "QUOTA $%d  DUE WHEN SPINS RUN OUT") % _run.quota()
	_quota_label.add_theme_color_override("font_color", COLOR_GREEN if met else COLOR_DIM)
	if _run.perks.is_empty():
		_perks_label.text = "PINK SLIP x%d = LAYOFF%s" % [_run.layoff_at(), "\nSLIPS LAND x2 THIS QUARTER" if review else ""]
	else:
		_perks_label.text = "  ".join(_run.perks.map(func(id): return LootPerks.info(id).name))
	_paytable.run = _run
	_paytable.queue_redraw()
	_wallet_label.text = "SHARDS %d   COMP TOKENS %d" % [_relics.shards, _relics.tokens]
	_spin_button.disabled = _busy or not _run.can_spin()
	_token_button.visible = _relics.tokens > 0
	_token_button.text = "TOKEN\nSPIN x%d" % _relics.tokens
	_token_button.disabled = _busy or _run.state != LootRun.State.SPINNING
	_machine.enabled = not _busy and _run.can_spin() and not _overlay.visible


# ---------------------------------------------------------------- run

func _new_run() -> void:
	_relics.reload()
	_run = LootRun.new(randi(), _relics.effects("loot"))
	_relics.bump("loot_runs")
	_banked = 0
	_busy = false
	_shown_coins = _run.coins
	_coins_label.text = "$%d" % _run.coins
	_machine.grid = _run.grid
	_machine.lights = 0
	_machine.tray_text = "PULL THE LEVER"
	_machine.tray_color = MachineView.BULB_ON
	_close_overlay()
	_refresh()


func _on_spin() -> void:
	if _run == null or _busy or not _run.can_spin() or _overlay.visible:
		return
	_spin(false)


func _on_token_spin() -> void:
	if _run == null or _busy or _run.state != LootRun.State.SPINNING:
		return
	if not _relics.use_token():
		_refresh()
		return
	_spin(true)


func _spin(bonus: bool) -> void:
	_busy = true
	_result = _run.spin(bonus)
	_machine.lights = 0
	_machine.tray_text = "BONUS SPIN!" if bonus else "..."
	_machine.tray_color = Color("#4cc9f0") if bonus else MachineView.BULB_ON
	_machine.start_spin(_run.grid, _run.weights())
	_play("lever")
	_refresh()
	while _machine.spinning():
		await get_tree().process_frame
	await _pay_out(_result)
	_bank_shards()
	_busy = false
	if _run.quarter_over():
		await get_tree().create_timer(0.6).timeout
		_end_quarter()
	_refresh()


## Light up each paying pattern in turn, coins rattling in with rising pitch.
func _pay_out(result: Dictionary) -> void:
	if result.layoff:
		_machine.lights = 2
		_machine.tray_text = "LAYOFF! %d PINK SLIPS" % result.slips
		_machine.tray_color = COLOR_RED
		_play("layoff")
		await get_tree().create_timer(1.1).timeout
		return
	var items: Array = result.items
	if items.is_empty():
		_machine.tray_text = "NOTHING. KEEP PULLING."
		_machine.tray_color = COLOR_DIM
		return
	_machine.lights = 1
	var step := clampf(0.5 - items.size() * 0.03, 0.18, 0.45)
	var pitch := 1.0
	var running := 0
	for p in items:
		var col: Color = LootSymbols.COLORS.get(p.symbol, Color.WHITE)
		_machine.highlight.assign(p.cells)
		_machine.highlight_color = col
		running += p.pay
		_machine.tray_text = "%s %s  +$%d" % [LootBalance.PATTERN_NAMES[p.kind], LootSymbols.symbol_name(p.symbol), p.pay]
		_machine.tray_color = col
		_machine.popup("+%d" % p.pay, p.cells[p.cells.size() / 2], col, p.kind == "jackpot")
		_play("coin", pitch)
		pitch = minf(pitch * 1.07, 2.4)
		await get_tree().create_timer(step).timeout
	_machine.highlight.clear()
	_machine.tray_text = "WIN $%d" % result.total
	_machine.tray_color = COLOR_GOLD
	if result.total >= 30 or items.size() >= 4:
		_play("bigwin")
	if result.shards > 0:
		_machine.tray_text += "  +%d SHARD%s" % [result.shards, "" if result.shards == 1 else "S"]
		_play("relic")


func _bank_shards() -> void:
	if _run.shards > _banked:
		_relics.add_shards(_run.shards - _banked)
		_banked = _run.shards


func _end_quarter() -> void:
	var paid := _run.quota()
	var state := _run.end_quarter()
	_bank_shards()
	match state:
		LootRun.State.FIRED:
			_play("fired")
			_show_fired()
		LootRun.State.PROMOTED:
			_relics.bump("loot_wins")
			_play("promoted")
			_show_promoted()
		LootRun.State.SHOP:
			_play("buy")
			_show_shop(paid)


# ---------------------------------------------------------------- overlays

func _open_overlay() -> void:
	for c in _overlay_box.get_children():
		c.queue_free()
	_overlay.visible = true
	if _run:
		_refresh()


func _close_overlay() -> void:
	_overlay.visible = false


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 200
	return l


func _show_title() -> void:
	_relics.reload()
	_run = null
	_open_overlay()
	_overlay_box.add_child(_centered(_label("LOOT\nMACHINE", 64, COLOR_GOLD)))
	_overlay_box.add_child(_centered(_label("Hit the quota four quarters running. Get promoted. Win relics that power up every game in the office.", 20, COLOR_INK)))
	var owned := _relics.owned.size()
	_overlay_box.add_child(_centered(_label("RELICS %d/%d   SHARDS %d   TOKENS %d" % [owned, OfficeRelics.ALL.size(), _relics.shards, _relics.tokens], 18, COLOR_PINK)))
	var start := _button("INSERT COIN", COLOR_RED, 32)
	start.custom_minimum_size.y = 120
	start.pressed.connect(_new_run)
	start.set_meta("pad_button", JOY_BUTTON_START)
	start.set_meta("pad_default", true)
	_overlay_box.add_child(start)
	var prize := _button("PRIZE COUNTER", COLOR_GOLD, 24)
	prize.pressed.connect(_show_prizes)
	_overlay_box.add_child(prize)
	_overlay_box.add_child(_centered(_label("Clear Pong stages and comedy sets to earn Comp Tokens: free bonus spins.", 16, COLOR_DIM)))


func _show_prizes() -> void:
	_relics.reload()
	_open_overlay()
	_overlay_box.add_child(_centered(_label("PRIZE COUNTER", 40, COLOR_GOLD)))
	_overlay_box.add_child(_centered(_label("SHARDS: %d" % _relics.shards, 24, COLOR_INK)))
	var last_game := ""
	for id in OfficeRelics.ORDER:
		var info := OfficeRelics.info(id)
		if info.game != last_game:
			last_game = info.game
			var head := _centered(_label(OfficeRelics.GAMES[info.game], 20, OfficeRelics.GAME_COLORS[info.game]))
			head.custom_minimum_size.y = 40
			head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			_overlay_box.add_child(head)
		var owned := _relics.has(id)
		var afford := _relics.shards >= int(info.price)
		var text := "%s\n%s\n%s" % [info.name, info.desc, "OWNED - ACTIVE" if owned else ("BUY: %d SHARDS" if afford else "%d SHARDS") % info.price]
		var b := _button(text, OfficeRelics.GAME_COLORS[info.game], 16)
		b.custom_minimum_size.y = 112
		if owned:
			# Owned relics glow in their game's colour but can't be bought again.
			b.add_theme_stylebox_override("disabled", b.get_theme_stylebox("pressed"))
			b.add_theme_color_override("font_disabled_color", COLOR_INK)
		b.disabled = owned or not afford
		b.pressed.connect(_buy_relic.bind(id))
		_overlay_box.add_child(b)
	var back := _button("BACK", COLOR_RED, 24)
	back.pressed.connect(_show_title)
	back.set_meta("pad_button", JOY_BUTTON_B)
	_overlay_box.add_child(back)


func _buy_relic(id: String) -> void:
	if _relics.buy(id):
		_play("relic")
	_show_prizes()


func _show_shop(paid: int) -> void:
	_open_overlay()
	_overlay_box.add_child(_centered(_label("BREAK ROOM", 40, COLOR_GOLD)))
	_overlay_box.add_child(_centered(_label("QUARTER %d DONE. PAID $%d.\nYOU HAVE $%d." % [_run.quarter + 1, paid, _run.coins], 20, COLOR_INK)))
	var next_q := _run.quarter + 1
	var next_text := "NEXT: ANNUAL REVIEW, QUOTA $%d (PINK SLIPS x2)" if next_q == LootBalance.QUARTERS - 1 else "NEXT: QUOTA $%d"
	_overlay_box.add_child(_centered(_label(next_text % LootBalance.QUOTAS[next_q], 18, COLOR_PINK)))
	var full := _run.perks.size() >= LootBalance.MAX_PERKS
	for id in _run.offers:
		var info := LootPerks.info(id)
		var b := _button("%s\n%s\n$%d" % [info.name, info.desc, info.cost], COLOR_GREEN, 18)
		b.custom_minimum_size.y = 120
		b.disabled = full or _run.coins < int(info.cost)
		b.pressed.connect(_buy_perk.bind(id, paid))
		_overlay_box.add_child(b)
	if _run.offers.is_empty():
		_overlay_box.add_child(_centered(_label("SOLD OUT", 20, COLOR_DIM)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var reroll := _button("REROLL $%d" % _run.reroll_cost, Color("#4cc9f0"), 18)
	reroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reroll.disabled = _run.coins < _run.reroll_cost
	reroll.pressed.connect(func():
		if _run.reroll():
			_play("buy")
		_show_shop(paid))
	row.add_child(reroll)
	var go := _button("BACK TO WORK", COLOR_RED, 18)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(func():
		_run.leave_shop()
		_machine.lights = 0
		_machine.tray_text = "QUOTA $%d. PULL!" % _run.quota()
		_machine.tray_color = COLOR_PINK if _run.is_review() else MachineView.BULB_ON
		_close_overlay()
		_refresh())
	row.add_child(go)
	_overlay_box.add_child(row)
	if not _run.perks.is_empty():
		_overlay_box.add_child(_centered(_label("YOURS: " + ", ".join(_run.perks.map(func(p): return LootPerks.info(p).name)), 16, COLOR_DIM)))


func _buy_perk(id: String, paid: int) -> void:
	if _run.buy(id):
		_play("buy")
	_show_shop(paid)


func _show_fired() -> void:
	_open_overlay()
	_overlay_box.add_child(_centered(_label("YOU'RE\nFIRED", 56, COLOR_RED)))
	var where := "THE ANNUAL REVIEW" if _run.is_review() else "QUARTER %d" % (_run.quarter + 1)
	_overlay_box.add_child(_centered(_label("Short of the $%d quota in %s.\nYou had $%d." % [_run.quota(), where, _run.coins], 20, COLOR_INK)))
	_overlay_box.add_child(_centered(_label("SHARDS KEPT: %d   (BANK: %d)" % [_run.shards, _relics.shards], 20, COLOR_GOLD)))
	_overlay_box.add_child(_centered(_label("Spend shards at the Prize Counter for relics, even when you lose.", 16, COLOR_DIM)))
	var again := _button("CLOCK IN AGAIN", COLOR_RED, 26)
	again.pressed.connect(_new_run)
	_overlay_box.add_child(again)
	var menu := _button("LOBBY", COLOR_GOLD, 22)
	menu.pressed.connect(_show_title)
	menu.set_meta("pad_button", JOY_BUTTON_B)
	_overlay_box.add_child(menu)


func _show_promoted() -> void:
	_relics.reload()
	_open_overlay()
	_overlay_box.add_child(_centered(_label("PROMOTED!", 52, COLOR_GOLD)))
	_overlay_box.add_child(_centered(_label("You survived the Annual Review with $%d to spare. +%d shards." % [_run.coins, _run.shards], 20, COLOR_INK)))
	var picks := _run.relic_choices(_relics.unowned())
	if picks.is_empty():
		_relics.add_shards(10)
		_overlay_box.add_child(_centered(_label("YOU OWN EVERY RELIC. +10 SHARDS INSTEAD.", 20, COLOR_PINK)))
		var ok := _button("LOBBY", COLOR_GOLD, 24)
		ok.pressed.connect(_show_title)
		_overlay_box.add_child(ok)
		return
	_overlay_box.add_child(_centered(_label("PICK AN OFFICE RELIC. IT'S YOURS FOR GOOD:", 18, COLOR_PINK)))
	for id in picks:
		var info := OfficeRelics.info(id)
		var b := _button("%s\n%s\nFOR %s" % [info.name, info.desc, OfficeRelics.GAMES[info.game]], OfficeRelics.GAME_COLORS[info.game], 16)
		b.custom_minimum_size.y = 130
		b.pressed.connect(_take_relic.bind(id))
		_overlay_box.add_child(b)


func _take_relic(id: String) -> void:
	_relics.grant(id)
	_play("relic")
	var info := OfficeRelics.info(id)
	_open_overlay()
	_overlay_box.add_child(_centered(_label(info.name, 40, OfficeRelics.GAME_COLORS[info.game])))
	_overlay_box.add_child(_centered(_label("%s.\nActive in %s from now on." % [info.desc, OfficeRelics.GAMES[info.game]], 20, COLOR_INK)))
	var ok := _button("BACK TO THE LOBBY", COLOR_GOLD, 22)
	ok.pressed.connect(_show_title)
	_overlay_box.add_child(ok)
