extends Control
## The cabinet, drawn in code: marquee with chasing bulbs, the 5x3 reel
## window, the lever and the coin tray. Everything is laid out in a fixed
## design space (DESIGN) and scaled to fit the control, so it looks the same
## upright and sideways. The main scene tells it what to show.

signal pulled
signal reel_stopped(reel: int)

const DESIGN := Vector2(700, 610)
const CELL := 112.0
const GAP := 8.0
const WIN_POS := Vector2(28, 132)
const PIXEL := 8.0
const SPIN_SPEED := 20.0  # cells per second
const FIRST_STOP := 0.55
const STOP_STEP := 0.2

const BODY := Color("#6b1a17")
const BODY_DARK := Color("#3d0d0c")
const BODY_EDGE := Color("#1c0605")
const BRASS := Color("#c9a24a")
const BRASS_DARK := Color("#7a5d20")
const GLASS := Color("#0c0a0b")
const BULB_ON := Color("#ffe27a")
const BULB_OFF := Color("#5a4316")
const RED := Color("#ff3b30")

var font: Font = preload("res://fonts/press_start_2p.ttf")
## Final symbols, grid[reel][row].
var grid: Array = []
## Cells to outline, and their colour (a paying pattern).
var highlight: Array[Vector2i] = []
var highlight_color := Color.WHITE
## 0 idle chase, 1 win flash, 2 layoff (red).
var lights := 0
## Text in the coin tray under the reels.
var tray_text := "PULL THE LEVER"
var tray_color := BULB_ON
var enabled := true

var _reels := []
var _t := 0.0
var _lever := 0.0
var _popups := []
var _rng := RandomNumberGenerator.new()
var _weights := {}


func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	for c in LootBalance.REELS:
		_reels.append({"active": false, "time": 0.0, "pos": 0.0, "strip": [], "bounce": 0.0})


func start_spin(final_grid: Array, weights: Dictionary) -> void:
	grid = final_grid
	_weights = weights
	highlight.clear()
	_lever = 1.0
	for c in LootBalance.REELS:
		var strip := []
		for k in 14:
			strip.append(LootGrid.pick(_rng, weights))
		_reels[c] = {"active": true, "time": FIRST_STOP + c * STOP_STEP, "pos": _rng.randf() * 10.0, "strip": strip, "bounce": 0.0}


func spinning() -> bool:
	for r in _reels:
		if r.active:
			return true
	return false


## A floating "+12" over a cell (design coordinates are worked out here).
func popup(text: String, cell: Vector2i, color: Color, big := false) -> void:
	_popups.append({"text": text, "pos": _cell_rect(cell).get_center(), "life": 1.1, "color": color, "big": big})


func _process(delta: float) -> void:
	_t += delta
	_lever = move_toward(_lever, 0.0, delta * 2.2)
	for c in _reels.size():
		var r: Dictionary = _reels[c]
		if r.active:
			r.time -= delta
			r.pos += SPIN_SPEED * delta
			if r.time <= 0.0:
				r.active = false
				r.bounce = 1.0
				reel_stopped.emit(c)
		else:
			r.bounce = move_toward(r.bounce, 0.0, delta * 6.0)
	for p in _popups:
		p.life -= delta
		p.pos.y -= delta * 60.0
	_popups = _popups.filter(func(p): return p.life > 0.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var press: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
	if press and enabled:
		pulled.emit()
		accept_event()


# ---------------------------------------------------------------- drawing

func _fit() -> Array:
	var s := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	var off := (size - DESIGN * s) * 0.5
	return [off, s]


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(WIN_POS + Vector2(cell.x * (CELL + GAP), cell.y * CELL), Vector2(CELL, CELL))


func _draw() -> void:
	var fit := _fit()
	draw_set_transform(fit[0], 0.0, Vector2(fit[1], fit[1]))
	var win_w := LootBalance.REELS * CELL + (LootBalance.REELS - 1) * GAP
	var win_h := LootBalance.ROWS * CELL
	var body := Rect2(4, 92, 640, 514)
	# Cabinet body with a bevel.
	draw_rect(body.grow(4), BODY_EDGE)
	draw_rect(body, BODY)
	draw_rect(Rect2(body.position, Vector2(body.size.x, 10)), BODY.lightened(0.15))
	draw_rect(Rect2(body.position + Vector2(0, body.size.y - 14), Vector2(body.size.x, 14)), BODY_DARK)
	# Rivets.
	for p in [Vector2(18, 106), Vector2(630, 106), Vector2(18, 592), Vector2(630, 592)]:
		draw_circle(p, 5, BRASS_DARK)
		draw_circle(p - Vector2(1, 1), 3, BRASS)
	# Reel window: brass frame, black glass.
	var win := Rect2(WIN_POS, Vector2(win_w, win_h))
	draw_rect(win.grow(12), BRASS_DARK)
	draw_rect(win.grow(8), BRASS)
	draw_rect(win.grow(4), BODY_EDGE)
	for c in LootBalance.REELS:
		var x := WIN_POS.x + c * (CELL + GAP)
		draw_rect(Rect2(x, WIN_POS.y, CELL, win_h), Color("#efe6d2"))
		_draw_reel(c, x)
		# Curved-glass shading: dark at the top and bottom of each reel.
		for k in 6:
			var a := 0.32 - k * 0.05
			draw_rect(Rect2(x, WIN_POS.y + k * 8, CELL, 8), Color(0, 0, 0, a))
			draw_rect(Rect2(x, WIN_POS.y + win_h - (k + 1) * 8, CELL, 8), Color(0, 0, 0, a))
		if c < LootBalance.REELS - 1:
			draw_rect(Rect2(x + CELL, WIN_POS.y, GAP, win_h), GLASS)
	# Hide strip symbols that scroll out of the window.
	draw_rect(Rect2(WIN_POS.x - 4, WIN_POS.y - CELL - 4, win_w + 8, CELL - 8), BODY)
	draw_rect(Rect2(WIN_POS.x - 12, WIN_POS.y - 12, win_w + 24, 8), BRASS_DARK)
	draw_rect(Rect2(WIN_POS.x - 8, WIN_POS.y - 8, win_w + 16, 4), BRASS)
	draw_rect(Rect2(WIN_POS.x - 4, WIN_POS.y - 4, win_w + 8, 4), BODY_EDGE)
	var below := WIN_POS.y + win_h
	draw_rect(Rect2(WIN_POS.x - 4, below + 12, win_w + 8, CELL), BODY)
	draw_rect(Rect2(WIN_POS.x - 12, below + 4, win_w + 24, 8), BRASS_DARK)
	draw_rect(Rect2(WIN_POS.x - 8, below + 4, win_w + 16, 4), BRASS)
	draw_rect(Rect2(WIN_POS.x - 4, below, win_w + 8, 4), BODY_EDGE)
	# Payline arrows on both sides.
	for r in LootBalance.ROWS:
		var y := WIN_POS.y + r * CELL + CELL * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(6, y - 9), Vector2(16, y), Vector2(6, y + 9)]), BULB_ON)
		draw_colored_polygon(PackedVector2Array([Vector2(642, y - 9), Vector2(632, y), Vector2(642, y + 9)]), BULB_ON)
	_draw_highlight()
	_draw_marquee()
	_draw_tray(Rect2(54, below + 30, 540, 64))
	_draw_lever()
	for p in _popups:
		var fs := 40 if p.big else 28
		var a := clampf(p.life * 2.0, 0.0, 1.0)
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at: Vector2 = p.pos + Vector2(-w * 0.5, fs * 0.5)
		draw_string_outline(font, at, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, a))
		draw_string(font, at, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(p.color, a))
	draw_set_transform(Vector2.ZERO)


func _draw_reel(c: int, x: float) -> void:
	var r: Dictionary = _reels[c] if c < _reels.size() else {}
	if r.get("active", false):
		var strip: Array = r.strip
		var base := int(floor(r.pos))
		var frac: float = r.pos - base
		for k in range(-1, LootBalance.ROWS + 1):
			var id: String = strip[posmod(base - k, strip.size())]
			var y := WIN_POS.y + (k + frac) * CELL
			_draw_symbol(id, Vector2(x, y), 0.75)
		# Speed streaks.
		for k in 3:
			draw_rect(Rect2(x + 10 + k * 40, WIN_POS.y, 3, LootBalance.ROWS * CELL), Color(1, 1, 1, 0.12))
		return
	if grid.size() <= c:
		return
	var drop: float = r.get("bounce", 0.0) * 14.0
	for row in LootBalance.ROWS:
		_draw_symbol(grid[c][row], Vector2(x, WIN_POS.y + row * CELL + drop), 1.0)


## A symbol's pixel art centred in a cell whose top-left is at.
func _draw_symbol(id: String, at: Vector2, alpha: float) -> void:
	var shape: Array = LootSymbols.SHAPES.get(id, [])
	var origin := at + Vector2(CELL - 10 * PIXEL, CELL - 10 * PIXEL) * 0.5
	# Outline pass, then colour.
	var outline := Color(0.08, 0.05, 0.05, alpha)
	for y in shape.size():
		var row: String = shape[y]
		for x in row.length():
			var ch := row[x]
			if ch != "." and ch != "w":
				draw_rect(Rect2(origin + Vector2(x, y) * PIXEL - Vector2(3, 3), Vector2(PIXEL + 6, PIXEL + 6)), outline)
	for y in shape.size():
		var row: String = shape[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var col: Color = LootSymbols.PALETTE[ch]
			if ch == "w":
				col.a *= 0.6 + 0.4 * sin(_t * 4.0 + x)
			draw_rect(Rect2(origin + Vector2(x, y) * PIXEL, Vector2(PIXEL, PIXEL)), Color(col, col.a * alpha))


func _draw_highlight() -> void:
	if highlight.is_empty():
		return
	var pulse := 0.6 + 0.4 * sin(_t * 18.0)
	var col := Color(highlight_color, pulse)
	var pts := PackedVector2Array()
	for cell in highlight:
		var rect := _cell_rect(cell)
		draw_rect(rect.grow(-3), col, false, 6.0)
		pts.append(rect.get_center())
	if pts.size() >= 2 and pts.size() <= 5:
		draw_polyline(pts, Color(highlight_color, 0.85), 8.0)


func _draw_marquee() -> void:
	var m := Rect2(30, 6, 588, 100)
	draw_rect(m.grow(6), BODY_EDGE)
	draw_rect(m, Color("#24080a"))
	draw_rect(m.grow(-14), Color("#3a0d10"))
	# Bulbs around the edge.
	var bulbs: Array[Vector2] = []
	var step := 28.0
	var x := m.position.x + 8.0
	while x <= m.end.x - 8.0:
		bulbs.append(Vector2(x, m.position.y + 7))
		x += step
	var y := m.position.y + 7 + step
	while y <= m.end.y - 7:
		bulbs.append(Vector2(m.end.x - 8, y))
		y += step
	x = m.end.x - 8.0
	while x >= m.position.x + 8.0:
		bulbs.append(Vector2(x, m.end.y - 7))
		x -= step
	y = m.end.y - 7 - step
	while y >= m.position.y + 7:
		bulbs.append(Vector2(m.position.x + 8, y))
		y -= step
	for i in bulbs.size():
		var on: bool
		var col := BULB_ON
		match lights:
			1:
				on = int(_t * 10.0) % 2 == i % 2
			2:
				on = int(_t * 6.0) % 2 == 0
				col = RED
			_:
				on = (i + int(_t * 9.0)) % 4 == 0
		draw_circle(bulbs[i], 6.5, col if on else BULB_OFF)
		if on:
			draw_circle(bulbs[i] - Vector2(1.5, 1.5), 2.5, Color(1, 1, 1, 0.8))
	var title := "LOOT MACHINE"
	var fs := 36
	var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(m.get_center().x - w * 0.5, m.get_center().y + fs * 0.5 - 2)
	var glow := RED if lights == 2 else Color("#ffcf3f")
	draw_string_outline(font, at + Vector2(0, 4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color("#160404"))
	draw_string(font, at + Vector2(0, 4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#160404"))
	draw_string(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, glow)


func _draw_tray(r: Rect2) -> void:
	draw_rect(r.grow(4), BRASS_DARK)
	draw_rect(r, Color("#120708"))
	var fs := 22
	var w := font.get_string_size(tray_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var a := 1.0 if lights != 0 or not enabled else 0.55 + 0.45 * sin(_t * 4.0)
	draw_string(font, Vector2(r.get_center().x - w * 0.5, r.get_center().y + fs * 0.5), tray_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(tray_color, a))


func _draw_lever() -> void:
	var base := Vector2(672, 360)
	draw_rect(Rect2(base.x - 24, base.y - 40, 26, 80), BODY_EDGE)
	draw_rect(Rect2(base.x - 22, base.y - 36, 22, 72), BRASS_DARK)
	# The knob swings from the top (rest) down past the pivot when pulled.
	var ang := lerpf(0.12, 2.95, _lever * _lever * (3.0 - 2.0 * _lever))
	var tip := base + Vector2(sin(ang) * 10.0, -cos(ang) * 190.0)
	draw_line(base, tip, BODY_EDGE, 14.0)
	draw_line(base, tip, Color("#cfcfcf"), 8.0)
	draw_circle(tip, 22, BODY_EDGE)
	draw_circle(tip, 18, RED)
	draw_circle(tip - Vector2(6, 6), 6, Color(1, 1, 1, 0.7))
