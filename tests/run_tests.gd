extends SceneTree

const TestRunnerClass = preload("res://tests/framework/test_runner.gd")

var _executed: bool = false

func _process(_delta: float) -> bool:
	if not _executed:
		_executed = true
		var runner = TestRunnerClass.new()
		var user_args = OS.get_cmdline_user_args()
		runner.parse_arguments(user_args)
		var exit_code = runner.run_all()
		quit(exit_code)
		return true
	return false
