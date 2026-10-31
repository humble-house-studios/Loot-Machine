class_name LootPerks
extends RefCounted
## Break Room perks: bought with coins between quarters, last one run.
## (Office relics are the permanent ones; see OfficeRelics.)

const ALL := {
	"espresso": {"name": "DOUBLE ESPRESSO", "desc": "Coffee pays x3", "cost": 6},
	"open_mic": {"name": "OPEN MIC NIGHT", "desc": "Mics land twice as often", "cost": 6},
	"rally": {"name": "LONG RALLY", "desc": "Pong Balls pay +3 each", "cost": 7},
	"choice": {"name": "AXIOM OF CHOICE", "desc": "Infinity Cards are wild", "cost": 14},
	"shredder": {"name": "PAPER SHREDDER", "desc": "Half as many Pink Slips", "cost": 8},
	"union": {"name": "UNION REP", "desc": "Layoff needs 2 more slips", "cost": 9},
	"overtime": {"name": "OVERTIME", "desc": "+2 spins every quarter", "cost": 10},
	"lines": {"name": "LONG LINES", "desc": "Rows pay double", "cost": 11},
	"bends": {"name": "BENDY STRAW", "desc": "Diagonals, zig, zag x2", "cost": 9},
	"interest": {"name": "401(K)", "desc": "+1 coin per 10 held each quarter", "cost": 5},
	"glue": {"name": "GLUE STICK", "desc": "Sticky Notes pay x3", "cost": 6},
	"treasure": {"name": "TREASURE MAP", "desc": "Loot Chests land twice as often", "cost": 9},
}


static func info(id: String) -> Dictionary:
	return ALL.get(id, {})
