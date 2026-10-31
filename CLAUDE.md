# Loot Machine: read before every change

A slot-machine roguelite that lives in the office of Killin' in Comedy and pays
out office relics for every game in the room. Godot 4.3, GDScript only.
Original game: genre-standard slot roguelite (reels, quotas, a shop), with its
own symbols, patterns and theme. Don't copy any specific existing game.

Samuel builds from his phone: Claude writes and pushes the code, GitHub builds a
web version, and he playtests it in Safari. Keep replies short and in plain words,
and handle git, builds and fixes yourself.
**End every reply with the play link:** https://humble-house-studios.github.io/Loot-Machine/

## Rules shared with the other games
- Phones = vertical (720x1280 base), Steam = horizontal (1280x720), stretch
  `canvas_items` + `expand`; the layout switches on screen shape.
- Compatibility renderer, nothing web-only, touch and mouse both work,
  touch targets at least 88 px, web build under ~30 MB.
- **It runs inside the office** in a SubViewport: `main.gd` must not touch the
  window when it isn't the root (`_owns_window()`). Input arrives as mouse events.
- No `class_name` that clashes with the comedy game's (Run, Battle, Balance,
  Crew, CardData, ...). Everything here is prefixed Loot* / Office*.
- The office fetches this repo into `res://games/loot/` (rewriting `res://`
  paths) via its `tools/fetch_games.sh`, dropping tests/tools/docs/integration.

## Code structure
- `engine/`: rules only, `RefCounted`, no scenes; seeded RNG per run.
  All numbers in `engine/loot_balance.gd`.
- `engine/office_relics.gd`: the shared save every game reads (see docs/ECOSYSTEM.md).
- `ecosystem/office_link.gd`: applies relics to Pong and Comedy by their variable
  names and earns Comp Tokens. Keep it in sync if those games rename things.
- Tests: `godot --headless -s tests/run_tests.gd` (run in CI before the build).
- Balance: `godot --headless -s res://tools/tune.gd` after changing numbers.
- Screenshots: `tools/screenshot.gd` under xvfb, check both orientations.
- Art is drawn in code (pixel shapes in `LootSymbols.SHAPES`). No image generation.
- Controller: `scenes/loot_pad.gd` (same as the comedy game's `pad_cursor.gd`):
  D-pad moves a frame over the buttons, A presses, X pulls, Y token spin, B back.
  Read the pad from events, never `Input` polling (the office shares one pad).
- Sounds: `tools/make_audio.py` (stdlib only), re-run after editing.

## Publishing
Push to `main` builds and publishes the web version (Settings → Pages →
Source: GitHub Actions must be on). The office picks up changes on its own
next build (killin-in-comedy's deploy fetches this repo).
