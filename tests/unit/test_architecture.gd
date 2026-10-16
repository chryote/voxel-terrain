class_name TestArchitecture
extends "res://tests/framework/test_case.gd"

## Architectural linter test ensuring pure decoupled layers:
## core, generation, meshing, streaming must NOT extend Node and must NOT reference world or player.

func test_pure_layers_have_no_scene_node_dependencies() -> void:
	var pure_dirs = [
		"res://src/core",
		"res://src/generation",
		"res://src/meshing",
		"res://src/streaming"
	]

	for dir_path in pure_dirs:
		var dir = DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".gd"):
				var full_path = dir_path.path_join(file_name)
				var file = FileAccess.open(full_path, FileAccess.READ)
				if file != null:
					var content = file.get_as_text()
					file.close()

					# Check 1: Must not extend Node or Node3D or Node2D
					assert_false("extends Node\n" in content or "extends Node " in content,
						"%s must not extend Node" % full_path)
					assert_false("extends Node3D" in content,
						"%s must not extend Node3D" % full_path)
					assert_false("extends Node2D" in content,
						"%s must not extend Node2D" % full_path)

					# Check 2: Must not reference world or player packages
					assert_false("res://src/world" in content,
						"%s must not depend on src/world" % full_path)
					assert_false("res://src/player" in content,
						"%s must not depend on src/player" % full_path)
					assert_false("VoxelWorld" in content,
						"%s must not reference VoxelWorld directly" % full_path)
					assert_false("PlayerMotor" in content,
						"%s must not reference PlayerMotor directly" % full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
