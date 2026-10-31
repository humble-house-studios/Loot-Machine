class_name LootSymbols
extends RefCounted
## The symbols on the reels. Each one comes from a game in the office, so the
## machine reads like a pile of everything on your desk.

## id -> name, which game it's from, coins per match, how often it lands.
const ALL := {
	"coffee": {"name": "COFFEE", "game": "office", "value": 3, "weight": 24},
	"note": {"name": "STICKY NOTE", "game": "office", "value": 3, "weight": 24},
	"mic": {"name": "MIC", "game": "comedy", "value": 5, "weight": 16},
	"ball": {"name": "PONG BALL", "game": "pong", "value": 5, "weight": 16},
	"inf": {"name": "INFINITY CARD", "game": "proof", "value": 8, "weight": 8},
	"chest": {"name": "LOOT CHEST", "game": "loot", "value": 15, "weight": 4},
	"slip": {"name": "PINK SLIP", "game": "office", "value": 0, "weight": 6},
}
const ORDER := ["coffee", "note", "mic", "ball", "inf", "chest", "slip"]
## Never part of a paying pattern; three of them is a Layoff.
const BAD := "slip"

## Pixel art, 10x10. Letters index PALETTE; '.' is see-through.
const SHAPES := {
	"coffee": [
		"...w..w...",
		"..w..w....",
		"...w..w...",
		".RRRRRR...",
		".RWWWWRRR.",
		".RWWWWR.R.",
		".RWWWWRRR.",
		".RWWWWR...",
		"..RRRR....",
		"DDDDDDDD..",
	],
	"note": [
		".YYYYYYYY.",
		".YYYYYYYY.",
		".YKKKKKYY.",
		".YYYYYYYY.",
		".YKKKKYYY.",
		".YYYYYYYY.",
		".YKKKYYYY.",
		".YYYYYYYO.",
		".YYYYYYOO.",
		"..........",
	],
	"mic": [
		"...GGGG...",
		"..GDGDGG..",
		"..GGDGDG..",
		"..GDGDGG..",
		"...GGGG...",
		"....DD....",
		"....RR....",
		"....RR....",
		"....RR....",
		"...DDDD...",
	],
	"ball": [
		"..........",
		"....YY....",
		"...YWYY...",
		"...YYYY...",
		"....YY....",
		"..........",
		"..........",
		".CCCCCCCC.",
		".CCCCCCCC.",
		"..........",
	],
	"inf": [
		".pppppppp.",
		".pVpppppp.",
		".pppppppp.",
		".pVVppVVp.",
		".VppVVppV.",
		".VppVVppV.",
		".pVVppVVp.",
		".pppppppp.",
		".ppppppVp.",
		".pppppppp.",
	],
	"chest": [
		"..........",
		"..NNNNNN..",
		".NYNNNNYN.",
		".NYNNNNYN.",
		".YYYYYYYY.",
		".NNNYYNNN.",
		".NNNYKNNN.",
		".NYNNNNYN.",
		".NYNNNNYN.",
		".NNNNNNNN.",
	],
	"slip": [
		".PPPPPPPP.",
		".PPPPPPPP.",
		".PKPPPPKP.",
		".PPKPPKPP.",
		".PPPKKPPP.",
		".PPPKKPPP.",
		".PPKPPKPP.",
		".PKPPPPKP.",
		".PPPPPPPP.",
		"..........",
	],
}

const PALETTE := {
	"K": Color("#141012"),
	"D": Color("#3a3438"),
	"G": Color("#a9a4a0"),
	"W": Color("#f4efe4"),
	"w": Color(0.9, 0.9, 0.9, 0.55),
	"R": Color("#c8302c"),
	"Y": Color("#f6c445"),
	"O": Color("#d98a2b"),
	"C": Color("#4cc9f0"),
	"V": Color("#9d4edd"),
	"p": Color("#efe3c2"),
	"N": Color("#7a4a26"),
	"P": Color("#ff8fb8"),
}

## Accent colour per symbol (pattern highlights, popups).
const COLORS := {
	"coffee": Color("#ff6b5e"),
	"note": Color("#f6c445"),
	"mic": Color("#ff5d8f"),
	"ball": Color("#4cc9f0"),
	"inf": Color("#b388ff"),
	"chest": Color("#ffd700"),
	"slip": Color("#ff8fb8"),
}


static func value(id: String) -> int:
	return int(ALL[id].value)


static func symbol_name(id: String) -> String:
	return ALL[id].name


static func base_weights() -> Dictionary:
	var w := {}
	for id in ORDER:
		w[id] = float(ALL[id].weight)
	return w
