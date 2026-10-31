extends SceneTree
## Balance check: plays autopilot runs and prints how far they get.
##   godot --headless -s res://tools/tune.gd
## RUNS=2000 sets the count; RELICS=1 plays with Spare Quarter + Petty Cash.

func _init() -> void:
	var runs := int(OS.get_environment("RUNS")) if OS.get_environment("RUNS") != "" else 1000
	var fx := {"spins": 1, "coins": 8} if OS.get_environment("RELICS") == "1" else {}
	var reached := [0, 0, 0, 0, 0]
	var spin_total := 0
	var spin_count := 0
	var layoffs := 0
	var shards := 0
	var best := 0
	for i in runs:
		var run := LootRun.new(i * 7919 + 1, fx)
		while run.state != LootRun.State.FIRED and run.state != LootRun.State.PROMOTED:
			if run.state == LootRun.State.SPINNING:
				if run.can_spin():
					var r := run.spin()
					spin_total += r.total
					spin_count += 1
					layoffs += 1 if r.layoff else 0
				else:
					run.end_quarter()
			elif run.state == LootRun.State.SHOP:
				_shop(run)
				run.leave_shop()
		reached[run.quarter + (1 if run.state == LootRun.State.PROMOTED else 0)] += 1
		shards += run.shards
		best = maxi(best, run.best_spin)
	print("runs %d   avg spin %.1f   layoffs %.1f%%   best spin %d   shards/run %.2f" % [
		runs, float(spin_total) / spin_count, 100.0 * layoffs / spin_count, best, float(shards) / runs])
	var names := ["fired Q1", "fired Q2", "fired Q3", "fired REVIEW", "PROMOTED"]
	for k in 5:
		print("  %-13s %5.1f%%" % [names[k], 100.0 * reached[k] / runs])
	quit()


## Autopilot shopper: buy the best-value perk it can afford, keeping a little
## buffer, and never reroll.
func _shop(run: LootRun) -> void:
	var prefer := ["lines", "choice", "overtime", "espresso", "glue", "bends", "open_mic", "rally", "shredder", "union", "treasure", "interest"]
	for id in prefer:
		if run.offers.has(id) and run.coins - LootPerks.info(id).cost >= 0:
			run.buy(id)
