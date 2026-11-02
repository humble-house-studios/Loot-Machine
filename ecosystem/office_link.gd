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
## Cube Desk: a solve from this level up pays a token; the record scramble pays 3.
const CUBE_MIN_LEVEL := 3
const TOKENS_PER_CUBE_BOSS := 3
const CUBE_BOSS := 9
## Proof Hand: each blind proven pays a token; a boss pays 2.
const TOKENS_PER_PROOF_BLIND := 1
const TOKENS_PER_PROOF_BOSS := 2

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
		"cube":
			tick_cube(node)
		"proof":
			tick_proof(node)


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


# ---------------------------------------------------------------- Cube Desk

var _cube_solves := -1


## Cube Desk (humble-house-studios/rubix scenes/main.gd): solves, last_level,
## hint_penalty. Sets the hint cost from Speed Lube; each new solve from level
## 3 up pays a Comp Token (3 for the world record scramble).
func tick_cube(main: Node) -> void:
	if not _has_vars(main, ["solves", "last_level", "hint_penalty"]):
		return
	var solves: int = main.get("solves")
	if _cube_solves < 0:
		_cube_solves = solves
		relics.reload()
		main.set("hint_penalty", float(relics.effects("cube").hint_penalty))
		return
	if solves > _cube_solves:
		_cube_solves = solves
		var lvl: int = main.get("last_level")
		relics.bump("cube_solves")
		if lvl >= CUBE_BOSS:
			_earn(TOKENS_PER_CUBE_BOSS, "RECORD SCRAMBLE")
		elif lvl >= CUBE_MIN_LEVEL:
			_earn(1, "CUBE LEVEL %d" % lvl)
		relics.reload()
		main.set("hint_penalty", float(relics.effects("cube").hint_penalty))


# ---------------------------------------------------------------- Proof Hand

var _proof_run: Object
var _proof_step := 0


## Proof Hand (humble-house-studios/proof-hand scripts/ui/main.gd): `run`
## (ProofRun: ante, stage, won, bonus_plays, bonus_discards, bonus_mult).
## A new run gets Chalk Nub / Eraser / Lucky Infinity; every blind proven
## pays a Comp Token (a boss pays 2).
func tick_proof(main: Node) -> void:
	if not ("run" in main):
		return
	var run = main.get("run")
	if run == null or not _has_vars(run, ["ante", "stage", "won", "bonus_plays", "bonus_discards", "bonus_mult"]):
		return
	var step: int = int(run.ante) * 3 + int(run.stage) + (1 if run.won else 0)
	if run != _proof_run:
		_proof_run = run
		_proof_step = step
		relics.reload()
		var fx := relics.effects("proof")
		run.bonus_plays = int(fx.hands)
		run.bonus_discards = int(fx.discards)
		run.bonus_mult = float(fx.mult)
		var n: int = (1 if fx.hands else 0) + (1 if fx.discards else 0) + (1 if fx.mult else 0)
		if n > 0:
			news.append("OFFICE RELICS: +%d IN PROOF HAND" % n)
		return
	if step > _proof_step:
		for s in range(_proof_step, step):
			_earn(TOKENS_PER_PROOF_BOSS if s % 3 == 2 else TOKENS_PER_PROOF_BLIND, "PROOF BOSS" if s % 3 == 2 else "BLIND PROVEN")
		_proof_step = step


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
