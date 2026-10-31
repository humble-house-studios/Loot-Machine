class_name LootGrid
extends RefCounted
## The 5x3 window of the machine: rolling it and finding what pays.
## A grid is an Array of REELS columns, each an Array of ROWS symbol ids,
## so grid[reel][row].


static func roll(rng: RandomNumberGenerator, weights: Dictionary) -> Array:
	var grid := []
	for c in LootBalance.REELS:
		var col := []
		for r in LootBalance.ROWS:
			col.append(pick(rng, weights))
		grid.append(col)
	return grid


static func pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for id in weights:
		total += maxf(0.0, weights[id])
	var roll_at := rng.randf() * total
	var last := ""
	for id in weights:
		var w: float = maxf(0.0, weights[id])
		if w <= 0.0:
			continue
		last = id
		if roll_at < w:
			return id
		roll_at -= w
	return last


static func count(grid: Array, id: String) -> int:
	var n := 0
	for col in grid:
		for s in col:
			if s == id:
				n += 1
	return n


## The symbol a run of cells pays as, or "" when they don't match.
## Wild symbols match anything except the Pink Slip.
static func match_symbol(cells: Array, wilds: Array) -> String:
	var sym := ""
	for s in cells:
		if s == LootSymbols.BAD:
			return ""
		if s in wilds:
			continue
		if sym == "":
			sym = s
		elif s != sym:
			return ""
	if sym == "":
		# All wild: pays as the first wild.
		return cells[0]
	return sym


## Every paying pattern on the grid: [{kind, symbol, cells: Array[Vector2i]}].
## Rows pay their longest run (3, 4 or 5); stacks are full reels; diagonals
## are any three steps up or down; zig and zag are V shapes across all five.
static func find_patterns(grid: Array, wilds: Array = []) -> Array:
	var out := []
	var rows := LootBalance.ROWS
	var reels := LootBalance.REELS
	# Rows: greedy longest runs, left to right.
	for r in rows:
		var c := 0
		while c <= reels - 3:
			var best := 0
			var best_sym := ""
			for length in range(reels - c, 2, -1):
				var cells := []
				for k in length:
					cells.append(grid[c + k][r])
				var sym := match_symbol(cells, wilds)
				if sym != "":
					best = length
					best_sym = sym
					break
			if best >= 3:
				var at: Array[Vector2i] = []
				for k in best:
					at.append(Vector2i(c + k, r))
				out.append({"kind": "line%d" % best, "symbol": best_sym, "cells": at})
				c += best
			else:
				c += 1
	# Stacks: a whole reel of one symbol.
	for c in reels:
		var sym := match_symbol(grid[c], wilds)
		if sym != "":
			var at: Array[Vector2i] = []
			for r in rows:
				at.append(Vector2i(c, r))
			out.append({"kind": "column", "symbol": sym, "cells": at})
	# Diagonals of three, both ways.
	for c in reels - 2:
		for dir in [1, -1]:
			var at: Array[Vector2i] = []
			var cells := []
			for k in 3:
				var r: int = k if dir == 1 else 2 - k
				at.append(Vector2i(c + k, r))
				cells.append(grid[c + k][r])
			var sym := match_symbol(cells, wilds)
			if sym != "":
				out.append({"kind": "diagonal", "symbol": sym, "cells": at})
	# Zig (top-middle-bottom-middle-top) and zag (the other way up).
	for spec in [["zig", [0, 1, 2, 1, 0]], ["zag", [2, 1, 0, 1, 2]]]:
		var at: Array[Vector2i] = []
		var cells := []
		for c in reels:
			at.append(Vector2i(c, spec[1][c]))
			cells.append(grid[c][spec[1][c]])
		var sym := match_symbol(cells, wilds)
		if sym != "":
			out.append({"kind": spec[0], "symbol": sym, "cells": at})
	# Jackpot: the whole window is one symbol.
	var all := []
	for col in grid:
		all.append_array(col)
	var jackpot := match_symbol(all, wilds)
	if jackpot != "":
		var at: Array[Vector2i] = []
		for c in reels:
			for r in rows:
				at.append(Vector2i(c, r))
		out.append({"kind": "jackpot", "symbol": jackpot, "cells": at})
	return out
