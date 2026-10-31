extends RefCounted
## Quarters, quotas, the shop and perks.

var _fails: Array[String] = []


func run() -> Array[String]:
	_fresh_run()
	_quota_and_firing()
	_shop()
	_perks_change_scores()
	_layoff()
	_relic_fx()
	_promotion()
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


func _fresh_run() -> void:
	var run := LootRun.new(1)
	_check(run.quarter == 0 and run.state == LootRun.State.SPINNING, "starts spinning in Q1")
	_check(run.spins_left == LootBalance.SPINS_PER_QUARTER, "full spins")
	_check(run.coins == LootBalance.START_COINS, "start coins")
	var before := run.coins
	var r := run.spin()
	_check(run.spins_left == LootBalance.SPINS_PER_QUARTER - 1, "spin uses a spin")
	_check(run.coins == before + r.total, "winnings are added")
	run.spin(true)
	_check(run.spins_left == LootBalance.SPINS_PER_QUARTER - 1, "token spin is free")


func _quota_and_firing() -> void:
	var run := LootRun.new(2)
	run.spins_left = 0
	run.coins = run.quota() - 1
	_check(run.quarter_over(), "out of spins = quarter over")
	_check(run.end_quarter() == LootRun.State.FIRED, "short of quota = fired")
	_check(run.spin().is_empty(), "no spins once fired")
	var ok := LootRun.new(3)
	ok.spins_left = 0
	ok.coins = ok.quota() + 5
	_check(ok.end_quarter() == LootRun.State.SHOP, "quota met = shop")
	_check(ok.coins == 5, "quota is paid out of coins")
	_check(ok.shards == LootBalance.SHARDS_PER_QUARTER, "a shard per quarter")


func _shop() -> void:
	var run := LootRun.new(4)
	run.spins_left = 0
	run.coins = run.quota() + 100
	run.end_quarter()
	_check(run.offers.size() == LootBalance.SHOP_CHOICES, "three offers")
	var id: String = run.offers[0]
	var coins := run.coins
	_check(run.buy(id), "can buy")
	_check(run.has(id) and run.coins == coins - LootPerks.info(id).cost, "perk owned and paid for")
	_check(not run.buy(id), "can't buy twice")
	var cost := run.reroll_cost
	_check(run.reroll() and run.reroll_cost == cost + LootBalance.REROLL_STEP, "reroll gets pricier")
	_check(not run.offers.has(id), "owned perks aren't offered")
	run.leave_shop()
	_check(run.quarter == 1 and run.state == LootRun.State.SPINNING, "next quarter")
	_check(run.quota() == LootBalance.QUOTAS[1], "quota grows")


func _perks_change_scores() -> void:
	var run := LootRun.new(5)
	var coffee := _g(["ccc..", ".....", "....."])
	var base: int = run.score(coffee).total
	_check(base == 3, "coffee row of 3 pays 3: %d" % base)
	run.perks.append("espresso")
	_check(run.score(coffee).total == 9, "double espresso: coffee x3")
	run.perks.append("lines")
	_check(run.score(coffee).total == 18, "long lines: rows x2")
	run.perks.assign(["choice"])
	_check(run.score(_g(["cicc.", ".....", "....."])).total == 6, "wild makes a row of 4 (3 x 2)")
	run.perks.assign(["overtime"])
	_check(run.spins_per_quarter() == LootBalance.SPINS_PER_QUARTER + 2, "overtime")


func _layoff() -> void:
	var run := LootRun.new(6)
	var g := _g(["cccs.", ".s...", "....s"])
	var r := run.score(g)
	_check(r.layoff and r.total == 0, "three slips = layoff, pays 0")
	run.perks.append("union")
	_check(not run.score(g).layoff and run.score(g).total == 3, "union rep needs five")
	var w := run.weights()
	run.quarter = LootBalance.QUARTERS - 1
	_check(run.weights().slip == w.slip * LootBalance.REVIEW_SLIP_X, "annual review: more slips")


func _relic_fx() -> void:
	var run := LootRun.new(7, {"spins": 1, "coins": 8})
	_check(run.spins_left == LootBalance.SPINS_PER_QUARTER + 1, "spare quarter relic")
	_check(run.coins == LootBalance.START_COINS + 8, "petty cash relic")


func _promotion() -> void:
	var run := LootRun.new(8)
	run.quarter = LootBalance.QUARTERS - 1
	run.spins_left = 0
	run.coins = run.quota()
	_check(run.end_quarter() == LootRun.State.PROMOTED, "clearing the review = promoted")
	_check(run.shards == LootBalance.SHARDS_PER_QUARTER + LootBalance.SHARDS_FOR_WIN, "win shards")
	var unowned: Array[String] = ["a", "b", "c", "d"]
	var picks := run.relic_choices(unowned)
	_check(picks.size() == 3 and picks[0] != picks[1], "three different relic choices")
