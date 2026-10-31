# The office ecosystem

Every game in the office shares one save: `user://office_relics.cfg`
(inside the office build they all share the same `user://`).

```
[meta]   save_version = 1
[relics] owned = ["battery", "lucky_mic", ...]
[wallet] shards = 4, tokens = 2
[stats]  all = {"pong_stages": 12, "comedy_sets": 5, "loot_runs": 7, "loot_wins": 1}
```

## Reading relics from a game
```gdscript
var fx := OfficeRelics.open().effects("pong")
# pong:   {hearts, shields, levels: {"wide": 1}, relics: ["phoenix"]}
# comedy: {heat, seconds, hand, full_mic}
# proof:  {hands, discards, mult}
# loot:   {spins, coins}
# office: {walk_speed}
```
Unknown keys can be ignored. Every write reloads the file first, so two games
writing at once don't undo each other.

## How the office applies them today
Phone Pong and Killin' in Comedy don't need to change. The office calls
`OfficeLink.tick(game, root_node)` every frame:
- **Pong:** when `title` and `game_over` go false at stage 1, it adds hearts,
  shields, `levels` and `relics`. Each new stage (not with the test-menu cheats on)
  pays 1 Comp Token.
- **Comedy:** each new `_battle` gets +Heat, +seconds, +hand size (and a refill)
  and full mic. Each `_run.set_index` step pays 2 Comp Tokens, +3 when the run is complete.

## Proof Hand
Proof Hand has no playable runs yet. When it does, either put it on an office
computer and add a `tick_proof` to `OfficeLink`, or read
`OfficeRelics.open().effects("proof")` in its `Game` autoload at run start
(+1 hand, +1 discard, +2 Mult).

## Adding a new game
1. Add its relics to `OfficeRelics.ALL`/`ORDER` with a `game` id, plus an
   `effects()` branch and a colour in `GAME_COLORS`.
2. Add a `tick_<game>` to `OfficeLink` that spots run starts and pays tokens.
3. Add a symbol for it on the reels in `LootSymbols` if it deserves one.
