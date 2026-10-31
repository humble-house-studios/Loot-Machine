class_name OfficeRelics
extends RefCounted
## Office relics: permanent rewards from the Loot Machine that power up every
## game in the room. One save file holds them, plus the Relic Shards you spend
## at the Prize Counter and the Comp Tokens the other games pay into the
## machine. Any game in the office reads it with:
##   OfficeRelics.open().effects("pong")
## Every change reloads the file first, so two games writing it never undo
## each other.

const SAVE_PATH := "user://office_relics.cfg"
const SAVE_VERSION := 1

const GAMES := {
	"comedy": "KILLIN' IN COMEDY",
	"pong": "PHONE PONG",
	"proof": "PROOF HAND",
	"loot": "LOOT MACHINE",
	"cube": "CUBE DESK",
	"office": "THE OFFICE",
}

## id -> name, what it does, which game it powers, Prize Counter price.
const ALL := {
	# Killin' in Comedy
	"lucky_mic": {"name": "LUCKY MIC", "desc": "Every set starts with +3 Heat", "game": "comedy", "price": 6},
	"wristwatch": {"name": "WRISTWATCH", "desc": "+10 seconds on every set", "game": "comedy", "price": 8},
	"notebook": {"name": "THE NOTEBOOK", "desc": "+1 card in hand every set", "game": "comedy", "price": 10},
	"lozenge": {"name": "THROAT LOZENGE", "desc": "Start every set with full mic", "game": "comedy", "price": 6},
	# Phone Pong
	"battery": {"name": "SPARE BATTERY", "desc": "Pong runs start with +1 heart", "game": "pong", "price": 6},
	"divider": {"name": "DESK DIVIDER", "desc": "Pong runs start with a shield", "game": "pong", "price": 6},
	"ruler": {"name": "LONG RULER", "desc": "Pong runs start with Wide Paddle", "game": "pong", "price": 8},
	"phoenix_mug": {"name": "PHOENIX MUG", "desc": "Pong runs start with Phoenix Feather", "game": "pong", "price": 12},
	# Proof Hand
	"chalk": {"name": "CHALK NUB", "desc": "+1 hand every blind", "game": "proof", "price": 6},
	"eraser": {"name": "ERASER", "desc": "+1 discard every blind", "game": "proof", "price": 6},
	"lucky_inf": {"name": "LUCKY INFINITY", "desc": "+2 Mult on every hand", "game": "proof", "price": 8},
	# Cube Desk
	"speed_lube": {"name": "SPEED LUBE", "desc": "Cube hints cost 1 second, not 2", "game": "cube", "price": 6},
	# The Loot Machine itself
	"spare_quarter": {"name": "SPARE QUARTER", "desc": "+1 spin every quarter", "game": "loot", "price": 8},
	"petty_cash": {"name": "PETTY CASH", "desc": "Machine runs start with +8 coins", "game": "loot", "price": 6},
	# The office
	"sneakers": {"name": "COMFY SNEAKERS", "desc": "Walk faster around the office", "game": "office", "price": 4},
}
const ORDER := [
	"lucky_mic", "wristwatch", "notebook", "lozenge",
	"battery", "divider", "ruler", "phoenix_mug",
	"chalk", "eraser", "lucky_inf",
	"speed_lube",
	"spare_quarter", "petty_cash",
	"sneakers",
]

const GAME_COLORS := {
	"comedy": Color("#ff5d8f"),
	"pong": Color("#4cc9f0"),
	"proof": Color("#b388ff"),
	"loot": Color("#ffd700"),
	"cube": Color("#3ee6c1"),
	"office": Color("#9be37a"),
}

var path := SAVE_PATH
var owned: Array[String] = []
var shards := 0
var tokens := 0
## Lifetime counters: pong_stages, comedy_sets, comedy_shows, loot_runs, loot_wins.
var stats := {}


static func open(save_path := SAVE_PATH) -> OfficeRelics:
	var r := OfficeRelics.new()
	r.path = save_path
	r.reload()
	return r


static func info(id: String) -> Dictionary:
	return ALL.get(id, {})


func reload() -> void:
	owned.clear()
	shards = 0
	tokens = 0
	stats = {}
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	# Version 1 is the first format; later versions migrate here.
	for id in cfg.get_value("relics", "owned", []):
		if ALL.has(id) and not owned.has(id):
			owned.append(id)
	shards = int(cfg.get_value("wallet", "shards", 0))
	tokens = int(cfg.get_value("wallet", "tokens", 0))
	stats = cfg.get_value("stats", "all", {})


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", SAVE_VERSION)
	cfg.set_value("relics", "owned", owned.duplicate())
	cfg.set_value("wallet", "shards", shards)
	cfg.set_value("wallet", "tokens", tokens)
	cfg.set_value("stats", "all", stats)
	cfg.save(path)


func has(id: String) -> bool:
	return owned.has(id)


func unowned() -> Array[String]:
	var out: Array[String] = []
	for id in ORDER:
		if not owned.has(id):
			out.append(id)
	return out


func grant(id: String) -> void:
	reload()
	if ALL.has(id) and not owned.has(id):
		owned.append(id)
	save()


## Buy a relic at the Prize Counter with shards.
func buy(id: String) -> bool:
	reload()
	if not ALL.has(id) or owned.has(id) or shards < int(ALL[id].price):
		return false
	shards -= int(ALL[id].price)
	owned.append(id)
	save()
	return true


func add_shards(n: int) -> void:
	reload()
	shards += n
	save()


## Comp Tokens: the other games pay these in. Capped so they can't pile up.
func add_tokens(n: int) -> void:
	reload()
	tokens = clampi(tokens + n, 0, LootBalance.MAX_TOKENS)
	save()


func use_token() -> bool:
	reload()
	if tokens <= 0:
		return false
	tokens -= 1
	save()
	return true


func bump(stat: String, n := 1) -> void:
	reload()
	stats[stat] = int(stats.get(stat, 0)) + n
	save()


func stat(name: String) -> int:
	return int(stats.get(name, 0))


## What a game should change at the start of a run (or set), from the relics
## owned. Games that don't know a key just ignore it.
func effects(game: String) -> Dictionary:
	var fx := {}
	match game:
		"comedy":
			fx.heat = 3 if has("lucky_mic") else 0
			fx.seconds = 10.0 if has("wristwatch") else 0.0
			fx.hand = 1 if has("notebook") else 0
			fx.full_mic = has("lozenge")
		"pong":
			fx.hearts = 1 if has("battery") else 0
			fx.shields = 1 if has("divider") else 0
			fx.levels = {"wide": 1} if has("ruler") else {}
			fx.relics = ["phoenix"] if has("phoenix_mug") else []
		"proof":
			fx.hands = 1 if has("chalk") else 0
			fx.discards = 1 if has("eraser") else 0
			fx.mult = 2 if has("lucky_inf") else 0
		"loot":
			fx.spins = 1 if has("spare_quarter") else 0
			fx.coins = 8 if has("petty_cash") else 0
		"cube":
			fx.hint_penalty = 1.0 if has("speed_lube") else 2.0
		"office":
			fx.walk_speed = 1.3 if has("sneakers") else 1.0
	return fx
