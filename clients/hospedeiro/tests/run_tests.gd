extends SceneTree
## Run: godot --headless --path clients/hospedeiro --script res://tests/run_tests.gd

const SUITES := [
	"res://tests/test_domain.gd",
	"res://tests/test_genome.gd",
	"res://tests/test_world.gd",
	"res://tests/test_host.gd",
	"res://tests/test_abilities.gd",
	"res://tests/test_every_ability.gd",
	"res://tests/test_dungeon.gd",
	"res://tests/test_organelles.gd",
	"res://tests/test_balance.gd",
	"res://tests/test_anatomy.gd",
	"res://tests/test_liver.gd",
	"res://tests/test_liver_dungeon.gd",
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
	"res://tests/test_jev_debug.gd",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var total := 0
	var failed := 0
	for path in SUITES:
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
