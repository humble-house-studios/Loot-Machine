class_name LootBalance
extends RefCounted
## Every Loot Machine number in one place, so tuning never means hunting
## through code. Check changes with: godot --headless -s res://tools/tune.gd

const REELS := 5
const ROWS := 3

## A run is four quarters. Each quarter you get some spins; when they run out
## you must hold the quota, which is paid out of your coins. Miss it: fired.
const QUARTERS := 4
const QUOTAS := [12, 28, 60, 110]
const SPINS_PER_QUARTER := 7
const START_COINS := 4
## The last quarter is the Annual Review: Pink Slips show up this much more.
const REVIEW_SLIP_X := 2.0

## Three or more Pink Slips anywhere on the grid = Layoff: that spin pays 0.
const LAYOFF_SLIPS := 3

## Pattern -> payout multiplier (times the symbol's value).
const PATTERN_MULT := {
	"line3": 1,
	"line4": 2,
	"line5": 4,
	"column": 1,
	"diagonal": 1,
	"zig": 4,
	"zag": 4,
	"jackpot": 10,
}
const PATTERN_NAMES := {
	"line3": "LINE OF 3",
	"line4": "LINE OF 4",
	"line5": "LINE OF 5",
	"column": "STACK",
	"diagonal": "DIAGONAL",
	"zig": "ZIG",
	"zag": "ZAG",
	"jackpot": "JACKPOT",
}

## Break Room shop between quarters.
const SHOP_CHOICES := 3
const MAX_PERKS := 5
const REROLL_COST := 2
## Each reroll in the same shop costs this much more.
const REROLL_STEP := 1
## 401(k) perk: +1 coin per this many held at the start of a quarter, capped.
const INTEREST_PER := 10
const INTEREST_CAP := 5

## Relic Shards (meta currency, kept even when fired).
const SHARDS_PER_QUARTER := 1
const SHARDS_FOR_WIN := 3
## Plus one per Loot Chest in a paying pattern.
const SHARDS_PER_CHEST_PATTERN := 1

## Comp Tokens: earned by playing the other games in the office; each one is
## a free bonus spin in the Loot Machine.
const MAX_TOKENS := 10
