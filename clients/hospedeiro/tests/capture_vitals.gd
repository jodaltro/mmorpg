extends SceneTree
## Screenshots of the body's vital signs in a healthy body and in a feverish one with a lung short of air (real renderer).
##   godot --path clients/hospedeiro --script res://tests/capture_vitals.gd -- <output_dir>


func _initialize() -> void:
	_run.call_deferred()


func _vitals(temperature: int, pulse: int, oxygen: int, inflammation: int, adrenaline: int, cortisol: int, insulin: int) -> Array:
	return [
		{"id": "temperatura", "label": "Temperatura", "value": temperature, "min": 360, "max": 410, "low": 365, "high": 375},
		{"id": "pulso", "label": "Pulso", "value": pulse, "min": 50, "max": 140, "low": 60, "high": 90},
		{"id": "oxigenio", "label": "Oxigênio", "value": oxygen, "min": 0, "max": 100, "low": 70, "high": 100},
		{"id": "glicose", "label": "Glicose", "value": 55, "min": 0, "max": 100, "low": 30, "high": 80},
		{"id": "inflamacao", "label": "Inflamação", "value": inflammation, "min": 0, "max": 100, "low": 0, "high": 30},
		{"id": "adrenalina", "label": "Adrenalina", "value": adrenaline, "min": 0, "max": 100, "low": 0, "high": 50},
		{"id": "cortisol", "label": "Cortisol", "value": cortisol, "min": 0, "max": 100, "low": 0, "high": 50},
		{"id": "insulina", "label": "Insulina", "value": insulin, "min": 0, "max": 100, "low": 10, "high": 70},
	]


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	DirAccess.make_dir_recursive_absolute(out_dir)
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	root.add_child(world)
	await create_timer(0.8).timeout
	world.vitals_panel.toggle()
	world.apply_body(_vitals(370, 70, 90, 0, 0, 0, 20))
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png(out_dir + "/vitals_healthy.png")
	world.set_fever(true)
	world.apply_body(_vitals(392, 118, 46, 78, 70, 55, 20))
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out_dir + "/vitals_fever.png")
	quit()
