class_name LootRun
extends RefCounted
## One run on the machine: four quarters, each with a few spins and a quota.
## Hold the quota when the spins run out or you're fired. Between quarters
## the Break Room sells perks. Clear the Annual Review (quarter 4) and you're
## promoted: pick an office relic to keep forever.

enum State { SPINNING, SHOP, PROMOTED, FIRED }

var state := State.SPINNING
## 0-based; QUARTERS - 1 is the Annual Review.
var quarter := 0
var coins := 0
var spins_left := 0
var perks: Array[String] = []
var grid: Array = []
## Relic Shards earned this run (banked as they're earned by the caller).
var shards := 0
var offers: Array[String] = []
var reroll_cost := LootBalance.REROLL_COST
## Office relic effects for the machine ({spins, coins}).
var fx := {}
var spins_total := 0
var best_spin := 0

var _rng := RandomNumberGenerator.new()


func _init(rng_seed := 0, loot_fx := {}) -> void:
	_rng.seed = rng_seed
	fx = loot_fx
	coins = LootBalance.START_COINS + int(fx.get("coins", 0))
	grid = LootGrid.roll(_rng, weights())
	_start_quarter()


func quota() -> int:
	return LootBalance.QUOTAS[mini(quarter, LootBalance.QUOTAS.size() - 1)]


func is_review() -> bool:
	return quarter == LootBalance.QUARTERS - 1


func has(perk: String) -> bool:
	return perks.has(perk)


func spins_per_quarter() -> int:
	return LootBalance.SPINS_PER_QUARTER + int(fx.get("spins", 0)) + (2 if has("overtime") else 0)


func layoff_at() -> int:
	return LootBalance.LAYOFF_SLIPS + (2 if has("union") else 0)


func wilds() -> Array:
	return ["inf"] if has("choice") else []


func weights() -> Dictionary:
	var w := LootSymbols.base_weights()
	if has("open_mic"):
		w.mic *= 2.0
	if has("treasure"):
		w.chest *= 2.0
	if has("shredder"):
		w.slip *= 0.5
	if is_review():
		w.slip *= LootBalance.REVIEW_SLIP_X
	return w


## Coins one symbol pays in a pattern, before the pattern's multiplier.
func symbol_value(id: String) -> int:
	var v := LootSymbols.value(id)
	match id:
		"coffee":
			if has("espresso"):
				v *= 3
		"note":
			if has("glue"):
				v *= 3
		"ball":
			if has("rally"):
				v += 3
	return v


func pattern_mult(kind: String) -> int:
	var m: int = LootBalance.PATTERN_MULT[kind]
	if has("lines") and kind.begins_with("line"):
		m *= 2
	if has("bends") and kind in ["diagonal", "zig", "zag"]:
		m *= 2
	return m


## Score a grid: {total, layoff, slips, items: [{kind, symbol, cells, pay}], shards}.
func score(g: Array) -> Dictionary:
	var slips := LootGrid.count(g, LootSymbols.BAD)
	var items := []
	var total := 0
	var chest_patterns := 0
	for p in LootGrid.find_patterns(g, wilds()):
		var pay := symbol_value(p.symbol) * pattern_mult(p.kind)
		p.pay = pay
		items.append(p)
		total += pay
		if p.symbol == "chest":
			chest_patterns += 1
	var layoff := slips >= layoff_at()
	if layoff:
		total = 0
		chest_patterns = 0
	return {
		"total": total,
		"layoff": layoff,
		"slips": slips,
		"items": items,
		"shards": chest_patterns * LootBalance.SHARDS_PER_CHEST_PATTERN,
	}


func can_spin() -> bool:
	return state == State.SPINNING and spins_left > 0


## Pull the lever. bonus = a Comp Token spin that doesn't use up a spin.
func spin(bonus := false) -> Dictionary:
	if state != State.SPINNING or (spins_left <= 0 and not bonus):
		return {}
	if not bonus:
		spins_left -= 1
	spins_total += 1
	grid = LootGrid.roll(_rng, weights())
	var result := score(grid)
	coins += result.total
	shards += result.shards
	best_spin = maxi(best_spin, result.total)
	return result


## When the spins are gone: pay the quota and go shopping, or get fired.
## Returns the state it lands in.
func end_quarter() -> State:
	if state != State.SPINNING:
		return state
	if coins < quota():
		state = State.FIRED
		return state
	coins -= quota()
	shards += LootBalance.SHARDS_PER_QUARTER
	if is_review():
		shards += LootBalance.SHARDS_FOR_WIN
		state = State.PROMOTED
		return state
	state = State.SHOP
	reroll_cost = LootBalance.REROLL_COST
	_roll_offers()
	return state


func quarter_over() -> bool:
	return state == State.SPINNING and spins_left <= 0


func buy(id: String) -> bool:
	if state != State.SHOP or not offers.has(id) or perks.size() >= LootBalance.MAX_PERKS:
		return false
	var cost: int = LootPerks.info(id).cost
	if coins < cost:
		return false
	coins -= cost
	perks.append(id)
	offers.erase(id)
	return true


func reroll() -> bool:
	if state != State.SHOP or coins < reroll_cost:
		return false
	coins -= reroll_cost
	reroll_cost += LootBalance.REROLL_STEP
	_roll_offers()
	return true


func leave_shop() -> void:
	if state != State.SHOP:
		return
	quarter += 1
	state = State.SPINNING
	_start_quarter()


func _start_quarter() -> void:
	spins_left = spins_per_quarter()
	if has("interest"):
		coins += mini(coins / LootBalance.INTEREST_PER, LootBalance.INTEREST_CAP)


func _roll_offers() -> void:
	var pool: Array[String] = []
	for id in LootPerks.ALL:
		if not perks.has(id):
			pool.append(id)
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	offers.assign(pool.slice(0, LootBalance.SHOP_CHOICES))


## Three relics to choose from when promoted (from those not owned yet).
func relic_choices(unowned: Array[String]) -> Array[String]:
	var pool := unowned.duplicate()
	var picks: Array[String] = []
	while picks.size() < 3 and not pool.is_empty():
		picks.append(pool.pop_at(_rng.randi_range(0, pool.size() - 1)))
	return picks
