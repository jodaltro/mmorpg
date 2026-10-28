extends SceneTree
## Plays the real game (real renderer, offline, default invaders) through every organ for a while, with every kind of cell in every organ,
## so the engine log shows any drawing or script error. Run it and read the log:
##   godot --path clients/hospedeiro --script res://tests/soak_regions.gd -- <seconds per organ> 2>&1 | grep -E "ERROR|SCRIPT|WARNING"

const ROLES := ["defesa", "limpeza", "vigilancia", "reparo", "amparo", "reciclagem", "depuracao", "filtracao", "simbiose", "transporte", "memoria", "suporte"]
const REGIONS := ["medula", "sangue", "coracao", "pulmao", "aorta", "figado", "baco", "intestino", "rim", "pele", "linfonodo", "cerebro"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := float(args[0]) if args.size() > 0 else 8.0
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	root.add_child(world)
	await create_timer(1.0).timeout
	var kills := 0
	var downs := 0
	for region in REGIONS:
		world.player.global_position = BioBodyMap.center_px(StringName(region))
		var pops: Array = []
		for role in ROLES:
			pops.append({"id": "%s_%s" % [role, region], "role": role, "region": region, "count": 30, "max": 40})
		world.live_regions = [StringName(region)]
		world.sync.crowd.set_populations(pops)
		await create_timer(seconds).timeout
		for w in world.sync.crowd.workers:
			if w.is_down():
				downs += 1
		print("SOAK %s: %d cells drawn, %d down, %d invaders" % [region, world.sync.crowd.count(), downs, get_nodes_in_group("viruses").size()])
	print("SOAK done")
	quit()
