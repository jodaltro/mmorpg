extends SceneTree
## An empirical check of the balance: each class, with its four abilities and a simple fighter AI (walk up, lash, cast whatever is ready),
## clears the same room of the granuloma. Prints time to clear and membrane lost; a class far from the others is out of balance.
##   godot --path clients/hospedeiro --script res://tests/balance_duel.gd
## (needs the real renderer for physics timing to match play; headless works too but is slower to settle)

const ROOMS := [{"id": "a", "name": "a", "kind": "wall"}, {"id": "b", "name": "b", "kind": "wall"}, {"id": "w", "name": "O anel", "kind": "wall"}]
const CLASSES := [&"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar"]
const RUNS := 3


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	root.add_child(world)
	await create_timer(0.5).timeout
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	var ctrl := world.player.get_node("Controller") as BioCellController
	for lineage in CLASSES:
		var times: Array[float] = []
		var losses: Array[float] = []
		for run in RUNS:
			world.genome.lineage = lineage
			world.genome.equipped = []
			world.player.combatant.set_genome(world.genome)
			world.player.set_active(true)
			world.player.combatant.reset_vitals()
			world.abilities.slots.clear()
			for id in BioAbilityCatalog.ids_of_class(lineage):
				world.abilities.learn(id)
			world.dungeon.finish(false)
			world.dungeon.start({"seed": 1000 + run * 77, "room": 2, "rooms": ROOMS, "modifier": null})
			while world.dungeon.grace_left() > 0.0:
				await create_timer(0.1).timeout
			var t0 := Time.get_ticks_msec()
			var hp0 := world.player.combatant.actor.vitals.membrane
			while Time.get_ticks_msec() - t0 < 45000 and world.player.combatant.actor.vitals.is_alive() and (world.dungeon.enemies().size() > 0 or Time.get_ticks_msec() - t0 < 500):
				var best := INF
				var target: BioCellActor = null
				for e in world.dungeon.enemies():
					var d := (e as BioCellActor).global_position.distance_to(world.player.global_position)
					if d < best:
						best = d
						target = e
				if target != null:
					var to := target.global_position - world.player.global_position
					ctrl.set_aim(to)
					ctrl.move(Vector2.ZERO if best < 90.0 else to.normalized())
					ctrl.lash()
					for slot in 4:
						if world.abilities.cooldown_fraction(slot) <= 0.0 and best < 7.0 * BioArt.UNIT:
							world.abilities.perform(slot)
				await create_timer(0.1).timeout
			var alive := world.player.combatant.actor.vitals.is_alive()
			times.append((Time.get_ticks_msec() - t0) / 1000.0 if alive else 99.0)
			losses.append(hp0 - world.player.combatant.actor.vitals.membrane)
		print("%s: clear %.1f s (runs %s), membrane lost %.0f" % [lineage, (times[0] + times[1] + times[2]) / 3.0, str(times), (losses[0] + losses[1] + losses[2]) / 3.0])
	quit()
