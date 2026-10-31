extends RefCounted
## The shared office save and the bridge into the other games.

const PATH := "user://test_office_relics.cfg"

var _fails: Array[String] = []


func run() -> Array[String]:
	DirAccess.remove_absolute(PATH)
	_save_round_trip()
	_two_writers()
	_effects()
	_pong_link()
	_comedy_link()
	_cube_link()
	DirAccess.remove_absolute(PATH)
	return _fails


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _save_round_trip() -> void:
	var r := OfficeRelics.open(PATH)
	_check(r.owned.is_empty() and r.shards == 0, "empty save")
	r.add_shards(10)
	_check(not r.buy("phoenix_mug"), "too pricey")
	_check(r.buy("battery") and r.shards == 4, "buy at the prize counter")
	_check(not r.buy("battery"), "can't buy twice")
	r.grant("notebook")
	var again := OfficeRelics.open(PATH)
	_check(again.has("battery") and again.has("notebook") and again.shards == 4, "saved and loaded")
	_check(not again.unowned().has("battery"), "unowned skips owned")
	again.add_tokens(99)
	_check(again.tokens == LootBalance.MAX_TOKENS, "tokens are capped")
	_check(again.use_token() and again.tokens == LootBalance.MAX_TOKENS - 1, "use a token")


func _two_writers() -> void:
	var a := OfficeRelics.open(PATH)
	var b := OfficeRelics.open(PATH)
	a.grant("chalk")
	b.add_shards(1)
	var c := OfficeRelics.open(PATH)
	_check(c.has("chalk") and c.shards == 5, "a stale copy doesn't undo another writer")


func _effects() -> void:
	var r := OfficeRelics.open(PATH)
	_check(r.effects("pong").hearts == 1, "battery -> +1 heart")
	_check(r.effects("comedy").hand == 1, "notebook -> +1 card")
	_check(r.effects("proof").hands == 1, "chalk -> +1 hand")
	_check(r.effects("office").walk_speed == 1.0, "no sneakers yet")
	for game in OfficeRelics.GAMES:
		_check(r.effects(game) is Dictionary and not r.effects(game).is_empty(), "effects for %s" % game)
	for id in OfficeRelics.ORDER:
		_check(OfficeRelics.GAMES.has(OfficeRelics.info(id).game), "%s belongs to a game" % id)
	_check(OfficeRelics.ORDER.size() == OfficeRelics.ALL.size(), "ORDER lists every relic")


## A stand-in with Phone Pong's variable names.
class FakePong extends Node:
	var title := true
	var game_over := false
	var stage := 1
	var points := 0
	var hearts := 3
	var shields := 0
	var levels := {}
	var relics: Array[String] = []
	var cheated := false


func _pong_link() -> void:
	var r := OfficeRelics.open(PATH)
	r.grant("phoenix_mug")
	r.grant("ruler")
	var tokens := OfficeRelics.open(PATH).tokens
	var link := OfficeLink.new(PATH)
	var pong := FakePong.new()
	link.tick_pong(pong)
	_check(pong.hearts == 3, "nothing on the title screen")
	pong.title = false
	link.tick_pong(pong)
	_check(pong.hearts == 4, "battery: +1 heart at run start")
	_check(pong.levels.get("wide", 0) == 1, "ruler: wide paddle")
	_check(pong.relics.has("phoenix"), "phoenix mug: phoenix feather")
	link.tick_pong(pong)
	_check(pong.hearts == 4, "applied once per run")
	pong.stage = 2
	link.tick_pong(pong)
	_check(OfficeRelics.open(PATH).tokens == tokens + 1, "clearing a stage pays a token")
	pong.cheated = true
	pong.stage = 3
	link.tick_pong(pong)
	_check(OfficeRelics.open(PATH).tokens == tokens + 1, "test-menu cheats pay nothing")
	pong.game_over = true
	link.tick_pong(pong)
	pong.game_over = false
	pong.stage = 1
	pong.hearts = 3
	pong.cheated = false
	link.tick_pong(pong)
	_check(pong.hearts == 4, "a new run gets the relics again")
	_check(not link.pop_news().is_empty(), "the office hears about it")
	pong.free()


class FakeBattle extends RefCounted:
	var crowd_energy := 10.0
	var heat_history: Array[float] = [10.0]
	var time_left := 60.0
	var set_length := 60.0
	var hand_size := 5
	var mic := 3.0
	var refills := 0

	func _refill_hand() -> void:
		refills += 1


class FakeRun extends RefCounted:
	var set_index := 0

	func is_complete() -> bool:
		return set_index >= 4


class FakeComedy extends Node:
	var _run: FakeRun
	var _battle: FakeBattle


func _comedy_link() -> void:
	var r := OfficeRelics.open(PATH)
	for id in ["lucky_mic", "wristwatch", "lozenge"]:
		r.grant(id)
	var link := OfficeLink.new(PATH)
	var main := FakeComedy.new()
	link.tick_comedy(main)
	main._run = FakeRun.new()
	main._battle = FakeBattle.new()
	link.tick_comedy(main)
	var b := main._battle
	_check(b.crowd_energy == 13.0 and b.heat_history[0] == 13.0, "lucky mic: +3 heat")
	_check(b.time_left == 70.0 and b.set_length == 70.0, "wristwatch: +10 s")
	_check(b.hand_size == 6 and b.refills == 1, "notebook: +1 card")
	_check(b.mic == 5.0, "lozenge: full mic")
	link.tick_comedy(main)
	_check(b.crowd_energy == 13.0, "applied once per set")
	var tokens := OfficeRelics.open(PATH).tokens
	main._run.set_index = 1
	main._battle = FakeBattle.new()
	link.tick_comedy(main)
	_check(OfficeRelics.open(PATH).tokens == mini(tokens + 2, LootBalance.MAX_TOKENS), "a cleared set pays 2 tokens")
	_check(main._battle.crowd_energy == 13.0, "next set gets relics too")
	main.free()


class FakeCube extends Node:
	var solves := 0
	var last_level := 0
	var hint_penalty := 2.0


func _cube_link() -> void:
	var r := OfficeRelics.open(PATH)
	r.grant("speed_lube")
	r.tokens = 0
	r.save()
	var link := OfficeLink.new(PATH)
	var cube := FakeCube.new()
	link.tick_cube(cube)
	_check(cube.hint_penalty == 1.0, "speed lube: hints cost 1 s")
	cube.solves = 1
	cube.last_level = 2
	link.tick_cube(cube)
	_check(OfficeRelics.open(PATH).tokens == 0, "easy levels pay nothing")
	cube.solves = 2
	cube.last_level = 5
	link.tick_cube(cube)
	_check(OfficeRelics.open(PATH).tokens == 1, "level 5 pays a token")
	cube.solves = 3
	cube.last_level = 9
	link.tick_cube(cube)
	_check(OfficeRelics.open(PATH).tokens == 4, "the record scramble pays 3")
	cube.free()
