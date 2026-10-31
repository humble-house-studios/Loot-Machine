class_name OfficeLink
extends RefCounted
## The wiring between the Loot Machine and the other games in the office.
## The office calls tick() every frame with each game's root node:
##   - Relics in: when a game starts a run (or a set), its relic effects are
##     applied to it, so the games themselves don't need to change.
##   - Tokens out: clearing a Pong stage or a comedy set pays Comp Tokens into
##     the machine (free bonus spins).
## Each game is read by duck typing (its own variable names), so if a game
## renames something the link just stops applying, it never crashes the game.

const TOKENS_PER_PONG_STAGE := 1
const TOKENS_PER_COMEDY_SET := 2
const TOKENS_PER_COMEDY_SHOW := 3

var relics: OfficeRelics
## What happened since the office last asked (for toasts): ["+1 TOKEN", ...].
var news: Array[String] = []

var _pong_run_live := false
var _pong_stage := 0
var _comedy_battle: Object
var _comedy_run: Object
var _comedy_set := 0


func _init(save_path := OfficeRelics.SAVE_PATH) -> void:
	relics = OfficeRelics.open(save_path)


func pop_news() -> Array[String]:
	var out := news.duplicate()
	news.clear()
	return out


## Office walk speed multiplier (Comfy Sneakers).
func walk_speed() -> float:
	return float(relics.effects("office").walk_speed)


func tick(game: String, node: Node) -> void:
	if node == null:
		return
	match game:
		"pong":
			tick_pong(node)
		"comedy":
			tick_comedy(node)


# ---------------------------------------------------------------- Phone Pong

## Pong (humble-house-studios/phone-pong main.gd): vars title, game_over,
## stage, points, hearts, shields, levels, relics, cheated.
func tick_pong(pong: Node) -> void:
	if not _has_vars(pong, ["title", "game_over", "stage", "points", "hearts", "shields", "levels", "relics"]):
		return
	var playing: bool = not pong.get("title") and not pong.get("game_over")
	var stage: int = pong.get("stage")
	if not playing:
		_pong_run_live = false
		return
	if not _pong_run_live:
		# A run just started (PLAY on the title, or a restart).
		_pong_run_live = true
		_pong_stage = stage
		if stage == 1:
			_apply_pong(pong)
		return
	if stage > _pong_stage:
		if not pong.get("cheated"):
			_earn(TOKENS_PER_PONG_STAGE * (stage - _pong_stage), "PONG STAGE")
			relics.bump("pong_stages", stage - _pong_stage)
		_pong_stage = stage
	elif stage < _pong_stage:
		_pong_stage = stage


func _apply_pong(pong: Node) -> void:
	relics.reload()
	var fx := relics.effects("pong")
	if fx.hearts > 0:
		pong.set("hearts", int(pong.get("hearts")) + fx.hearts)
	if fx.shields > 0:
		pong.set("shields", int(pong.get("shields")) + fx.shields)
	var levels: Dictionary = pong.get("levels")
	for id in fx.levels:
		levels[id] = int(levels.get(id, 0)) + fx.levels[id]
	var owned = pong.get("relics")
	for id in fx.relics:
		if not owned.has(id):
			owned.append(id)
	var n: int = fx.relics.size() + fx.levels.size() + (1 if fx.hearts else 0) + (1 if fx.shields else 0)
	if n > 0:
		news.append("OFFICE RELICS: +%d IN PONG" % n)


# ---------------------------------------------------------------- Killin' in Comedy

## Comedy (humble-house-studios/killin-in-comedy scenes/main.gd): _run (Run)
## and _battle (Battle). A new Battle object = a new set has started.
func tick_comedy(main: Node) -> void:
	if not _has_vars(main, ["_run", "_battle"]):
		return
	var run = main.get("_run")
	var battle = main.get("_battle")
	if run != _comedy_run:
		_comedy_run = run
		_comedy_set = int(run.get("set_index")) if run else 0
	if run:
		var set_index: int = run.get("set_index")
		if set_index > _comedy_set:
			var cleared := set_index - _comedy_set
			_earn(TOKENS_PER_COMEDY_SET * cleared, "SET CLEARED")
			relics.bump("comedy_sets", cleared)
			if run.has_method("is_complete") and run.is_complete():
				_earn(TOKENS_PER_COMEDY_SHOW, "HEADLINER")
				relics.bump("comedy_shows")
		_comedy_set = set_index
	if battle != null and battle != _comedy_battle:
		_comedy_battle = battle
		_apply_comedy(battle)


func _apply_comedy(battle: Object) -> void:
	relics.reload()
	var fx := relics.effects("comedy")
	var n := 0
	if fx.heat > 0 and "crowd_energy" in battle:
		battle.crowd_energy = battle.crowd_energy + fx.heat
		var hist = battle.get("heat_history")
		if hist is Array and not hist.is_empty():
			hist[hist.size() - 1] = battle.crowd_energy
		n += 1
	if fx.seconds > 0 and "time_left" in battle:
		battle.time_left = battle.time_left + fx.seconds
		battle.set_length = battle.set_length + fx.seconds
		n += 1
	if fx.hand > 0 and "hand_size" in battle:
		battle.hand_size = battle.hand_size + fx.hand
		if battle.has_method("_refill_hand"):
			battle._refill_hand()
		n += 1
	if fx.full_mic and "mic" in battle:
		battle.mic = 5.0
		n += 1
	if n > 0:
		news.append("OFFICE RELICS: +%d ON STAGE" % n)


# ---------------------------------------------------------------- helpers

func _earn(n: int, why: String) -> void:
	if n <= 0:
		return
	relics.add_tokens(n)
	news.append("+%d COMP TOKEN%s  (%s)" % [n, "" if n == 1 else "S", why])


static func _has_vars(node: Object, names: Array) -> bool:
	for n in names:
		if not (n in node):
			return false
	return true
