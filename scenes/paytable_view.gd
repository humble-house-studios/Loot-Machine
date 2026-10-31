extends Control
## The paytable under (or beside) the machine: what each symbol pays per
## match and what each pattern multiplies it by, with this run's perks in.

const PIXEL := 4.0

var font: Font = preload("res://fonts/press_start_2p.ttf")
var run: LootRun


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var syms: Array = LootSymbols.ORDER
	var cols := 2 if w < 900 else 4
	var row_h := 52.0
	var rows := int(ceil(syms.size() / float(cols)))
	var need := 34.0 + rows * row_h + 70.0
	if size.y < need * 0.6:
		return
	var s := minf(1.0, size.y / need)
	var top := maxf(0.0, (size.y - need * s) * 0.5)
	draw_set_transform(Vector2(0, top), 0.0, Vector2(s, s))
	var span := w / s
	_text("PAYS PER MATCH", Vector2(span * 0.5, 18), 16, Color(1, 1, 1, 0.55), true)
	var col_w := span / cols
	for i in syms.size():
		var id: String = syms[i]
		var at := Vector2((i % cols) * col_w + 12, 34 + (i / cols) * row_h)
		_icon(id, at)
		var label: String
		if id == LootSymbols.BAD:
			label = "LAYOFF AT %d" % (run.layoff_at() if run else LootBalance.LAYOFF_SLIPS)
		else:
			var v := run.symbol_value(id) if run else LootSymbols.value(id)
			var wild := " WILD" if run and run.wilds().has(id) else ""
			label = "$%d%s" % [v, wild]
		var boosted := run != null and id != LootSymbols.BAD and run.symbol_value(id) > LootSymbols.value(id)
		var col: Color = Color("#7ee081") if boosted else LootSymbols.COLORS[id]
		_text(label, at + Vector2(54, 30), 16, col)
	var y := 34 + rows * row_h + 16
	var parts := []
	for kind in ["line3", "line4", "line5", "column", "diagonal", "zig", "jackpot"]:
		var m: int = run.pattern_mult(kind) if run else LootBalance.PATTERN_MULT[kind]
		var short: String = {"line3": "ROW3", "line4": "ROW4", "line5": "ROW5", "column": "STACK", "diagonal": "DIAG", "zig": "ZIG/ZAG", "jackpot": "FULL"}[kind]
		parts.append("%s x%d" % [short, m])
	var half := int(ceil(parts.size() / 2.0))
	_text("  ".join(parts.slice(0, half)), Vector2(span * 0.5, y), 14, Color(1, 0.86, 0.5, 0.85), true)
	_text("  ".join(parts.slice(half)), Vector2(span * 0.5, y + 26), 14, Color(1, 0.86, 0.5, 0.85), true)
	draw_set_transform(Vector2.ZERO)


func _icon(id: String, at: Vector2) -> void:
	var shape: Array = LootSymbols.SHAPES[id]
	for y in shape.size():
		var row: String = shape[y]
		for x in row.length():
			var ch := row[x]
			if ch == "." or ch == "w":
				continue
			draw_rect(Rect2(at + Vector2(x, y) * PIXEL, Vector2(PIXEL, PIXEL)), LootSymbols.PALETTE[ch])


func _text(t: String, at: Vector2, fs: int, col: Color, centered := false) -> void:
	var p := at
	if centered:
		p.x -= font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5
	draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color.BLACK)
	draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
