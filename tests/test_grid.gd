extends RefCounted
## Pattern finding on hand-built grids.

var _fails: Array[String] = []


func run() -> Array[String]:
	_rows()
	_stack_and_diagonal()
	_zig_zag_jackpot()
	_wilds()
	_slips_never_pay()
	_roll_weights()
	_art()
	return _fails


## Build a grid from 3 row strings of 5 letters (reels left to right);
## "." keeps the pattern-free background (notes, mics, balls).
func _g(rows: Array) -> Array:
	var bg := ["nnmmn", "mnbmm", "nmmnb"]
	var key := {"c": "coffee", "n": "note", "m": "mic", "b": "ball", "i": "inf", "x": "chest", "s": "slip"}
	var grid := []
	for c in 5:
		var col := []
		for r in 3:
			var ch: String = rows[r][c]
			col.append(key[bg[r][c] if ch == "." else ch])
		grid.append(col)
	return grid


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _kinds(grid: Array, wilds := []) -> Array:
	return LootGrid.find_patterns(grid, wilds).map(func(p): return p.kind + ":" + p.symbol)


func _rows() -> void:
	_check(_kinds(_g([".....", ".....", "....."])).is_empty(), "background pays nothing")
	_check(_kinds(_g(["ccc..", ".....", "....."])) == ["line3:coffee"], "row of 3 pays once")
	_check(_kinds(_g(["cccc.", ".....", "....."])) == ["line4:coffee"], "row of 4 pays as a 4, not 3s")
	_check(_kinds(_g([".....", "ccccc", "....."])) == ["line5:coffee"], "row of 5")
	_check(_kinds(_g([".....", ".....", "..ccc"])) == ["line3:coffee"], "row of 3 at the right edge")
	_check(_kinds(_g(["c.c.c", ".....", "....."])).is_empty(), "broken row pays nothing")


func _stack_and_diagonal() -> void:
	_check(_kinds(_g(["c....", "c....", "c...."])) == ["column:coffee"], "full reel stack")
	_check(_kinds(_g(["c....", ".c...", "..c.."])) == ["diagonal:coffee"], "diagonal down")
	_check(_kinds(_g(["....c", "...c.", "..c.."])) == ["diagonal:coffee"], "diagonal up")


func _zig_zag_jackpot() -> void:
	var zig := _kinds(_g(["x...x", ".x.x.", "..x.."]))
	_check(zig.has("zig:chest"), "zig across five reels: %s" % [zig])
	_check(zig.count("diagonal:chest") == 2, "zig contains two diagonals")
	var zag := _kinds(_g(["..x..", ".x.x.", "x...x"]))
	_check(zag.has("zag:chest") and not zag.has("zig:chest"), "zag")
	var jack := _kinds(_g(["mmmmm", "mmmmm", "mmmmm"]))
	_check(jack.has("jackpot:mic"), "jackpot")
	_check(jack.count("line5:mic") == 3 and jack.count("column:mic") == 5, "jackpot pays every line too")


func _wilds() -> void:
	var g := _g(["cicc.", ".....", "....."])
	_check(_kinds(g).is_empty(), "infinity isn't wild without the perk")
	_check(_kinds(g, ["inf"]) == ["line4:coffee"], "wild infinity joins a row")
	var all_wild := _kinds(_g(["iiis.", ".....", "....."]), ["inf"])
	_check(all_wild.has("line3:inf"), "all wild pays as infinity: %s" % [all_wild])
	_check(all_wild.has("diagonal:note"), "a wild finishes a diagonal of notes")
	_check(_kinds(_g(["sis..", ".....", "....."]), ["inf"]).is_empty(), "wild never matches a pink slip")


func _slips_never_pay() -> void:
	_check(_kinds(_g(["sss..", ".....", "....."])).is_empty(), "pink slips don't make lines")


func _roll_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var only := {"coffee": 0.0, "mic": 5.0, "slip": 0.0}
	for i in 50:
		if LootGrid.pick(rng, only) != "mic":
			_check(false, "zero weights never land")
			return
	var g := LootGrid.roll(rng, LootSymbols.base_weights())
	_check(g.size() == 5 and g[0].size() == 3, "grid is 5 reels x 3 rows")


func _art() -> void:
	for id in LootSymbols.ORDER:
		var shape: Array = LootSymbols.SHAPES.get(id, [])
		_check(shape.size() == 10, "%s art is 10 rows" % id)
		for row: String in shape:
			_check(row.length() == 10, "%s art row '%s' is 10 wide" % [id, row])
			for ch in row:
				_check(ch == "." or LootSymbols.PALETTE.has(ch), "%s uses a known colour '%s'" % [id, ch])
		_check(LootSymbols.COLORS.has(id), "%s has an accent colour" % id)
