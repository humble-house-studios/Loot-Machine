# Loot Machine

A slot-machine roguelite that sits in the corner of the office in
[Killin' in Comedy](https://github.com/humble-house-studios/killin-in-comedy)
and pays out **office relics**, permanent power-ups for every game in the room.

**Play it on its own:** https://humble-house-studios.github.io/Loot-Machine/
**Play it in the office:** https://humble-house-studios.github.io/killin-in-comedy/office/

## How it plays
- Pull the lever. Five reels, three rows, symbols from every game on your desk:
  Coffee and Sticky Notes (the office), Mics (Killin' in Comedy), Pong Balls
  (Phone Pong), Infinity Cards (Proof Hand) and Loot Chests.
- Rows of 3/4/5, full-reel stacks, diagonals, zig/zag Vs and a full-window
  jackpot all pay. Three **Pink Slips** anywhere = **Layoff**: that spin pays 0.
- Four quarters. When a quarter's spins run out you must hold the **quota**
  ($12, $28, $60, then $110 at the Annual Review, where slips land twice as often).
  Miss it and you're fired.
- Between quarters the **Break Room** sells perks for this run only
  (Double Espresso, Axiom of Choice wilds, Overtime, Long Lines...).
- Get promoted and pick an **office relic** to keep forever. Shards from every run,
  won or lost, buy relics at the **Prize Counter**.

## How it connects the office
| Game | What the machine gives it | What it gives the machine |
|---|---|---|
| Killin' in Comedy | Lucky Mic (+3 Heat), Wristwatch (+10 s), The Notebook (+1 card), Throat Lozenge (full mic) | 2 Comp Tokens per set cleared, +3 for headlining |
| Phone Pong | Spare Battery (+1 heart), Desk Divider (shield), Long Ruler (Wide Paddle), Phoenix Mug (Phoenix Feather) | 1 Comp Token per stage cleared |
| Proof Hand | Chalk Nub (+1 hand), Eraser (+1 discard), Lucky Infinity (+2 Mult), ready for when its runs are playable | |
| Cube Desk | Speed Lube (hints cost 1 s instead of 2) | 1 Comp Token per solve from level 3, 3 for the record scramble |
| Loot Machine | Spare Quarter (+1 spin a quarter), Petty Cash (+8 coins) | |
| The office | Comfy Sneakers (walk faster) | |

Comp Tokens are free bonus spins. Details for game authors: [`docs/ECOSYSTEM.md`](docs/ECOSYSTEM.md).

## Code
- `engine/`: pure rules (no scenes): `loot_run.gd`, `loot_grid.gd`, `loot_symbols.gd`,
  `loot_perks.gd`, `loot_balance.gd` (every number), `office_relics.gd` (the shared save).
- `ecosystem/office_link.gd`: the bridge the office ticks to apply relics and earn tokens.
- `scenes/`: the cabinet (`machine_view.gd`), paytable and UI, all drawn in code.
- Tests: `godot --headless -s tests/run_tests.gd`
- Balance: `godot --headless -s res://tools/tune.gd` (`RELICS=1` to include relics)
- Screenshots: see the header of `tools/screenshot.gd`. Sounds: `python3 tools/make_audio.py`.
