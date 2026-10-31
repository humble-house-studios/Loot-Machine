extends SceneTree
## Renders the Loot Machine screens to PNGs in $OUT (needs a display):
##   OUT=/some/dir xvfb-run -a -s "-screen 0 1280x1280x24" \
##     godot --rendering-driver opengl3 --resolution 720x1280 -s res://tools/screenshot.gd
## Use --resolution 1280x720 for the sideways (Steam) layout.
## Shots: 0 title, 1 mid-payout, 2 break room, 3 prize counter, 4 promoted.

var main


func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	main._relics.add_shards(14)
	main._relics.add_tokens(2)
	main._show_title()
	await _frames(20)
	await _shot(0)
	main._new_run()
	main._run.perks.assign(["espresso", "choice"])
	await _frames(5)
	# Find a seed that pays a few patterns, so the payout shows off.
	var best_seed := 0
	for s in 400:
		var probe := LootRun.new(s)
		probe.perks.assign(main._run.perks)
		if probe.spin().items.size() >= 3:
			best_seed = s
			break
	main._run._rng.seed = best_seed
	main._on_spin()
	await _frames(95)
	await _shot(1)
	await _frames(240)
	main._run.spins_left = 0
	main._run.coins = main._run.quota() + 30
	main._end_quarter()
	await _frames(20)
	await _shot(2)
	main._show_prizes()
	await _frames(20)
	await _shot(3)
	main._run = LootRun.new(5)
	main._show_promoted()
	await _frames(20)
	await _shot(4)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(i: int) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var out := OS.get_environment("OUT")
	img.save_png("%s/shot_%d.png" % [out if out != "" else ".", i])
