extends SceneTree
## Run: godot --headless --path clients/hospedeiro --script res://tests/run_tests.gd [-- part_of_a_suite_name]

const SUITES := [
	"res://tests/test_lash_targets.gd",
	"res://tests/test_personal_world.gd",
	"res://tests/test_navigation.gd",
	"res://tests/test_progression.gd",
	"res://tests/test_journey.gd",
	"res://tests/test_net_responsiveness.gd",
	"res://tests/test_tutorial.gd",
	"res://tests/test_evolution_presentation.gd",
	"res://tests/test_combat_feedback.gd",
	"res://tests/test_latency.gd",
	"res://tests/test_net_protocol.gd",
	"res://tests/test_network_server.gd",
	"res://tests/test_domain.gd",
	"res://tests/test_genome.gd",
	"res://tests/test_world.gd",
	"res://tests/test_host.gd",
	"res://tests/test_abilities.gd",
	"res://tests/test_every_ability.gd",
	"res://tests/test_organelles.gd",
	"res://tests/test_balance.gd",
	"res://tests/test_anatomy.gd",
	"res://tests/test_liver.gd",
	"res://tests/test_body_world.gd",
	"res://tests/test_body_state.gd",
	"res://tests/test_exploration.gd",
	"res://tests/test_design.gd",
	"res://tests/test_effect_physics.gd",
	"res://tests/test_projectile.gd",
	"res://tests/test_focus.gd",
	"res://tests/test_modes.gd",
	"res://tests/test_body_panel.gd",
	"res://tests/test_procedural.gd",
	"res://tests/test_organs.gd",
	"res://tests/test_new_classes.gd",
	"res://tests/test_redone_abilities.gd",
	"res://tests/test_jev_debug.gd",
	"res://tests/test_touch.gd",
	"res://tests/test_living_body.gd",
	"res://tests/test_living_world.gd",
	"res://tests/test_calling.gd",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var total := 0
	var failed := 0
	var only := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	for path in SUITES:
		if only != "" and not path.contains(only):
			continue
		var suite: TestCase = load(path).new()
		suite.tree = self
		for method in suite.get_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			total += 1
			suite.failures.clear()
			await suite.before_each()
			await suite.call(name)
			await suite.after_each()
			if suite.failures.is_empty():
				print("PASS  %s::%s" % [path.get_file(), name])
			else:
				failed += 1
				for f in suite.failures:
					print("FAIL  %s::%s  %s" % [path.get_file(), name, f])
	print("---- %d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
