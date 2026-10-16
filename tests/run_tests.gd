extends SceneTree

const TestRunnerClass = preload("res://tests/framework/test_runner.gd")

var _executed: bool = false

func _init() -> void:
	var runner = TestRunnerClass.new()
	var user_args = OS.get_cmdline_user_args()
	runner.parse_arguments(user_args)
	var exit_code = runner.run_all()
	quit(exit_code)


