class_name RegressionCase
extends "res://tests/framework/test_case.gd"

## Base class for regression tests that compare deterministic output snapshots against golden files.

const GOLDEN_DIR: String = "res://tests/regression/golden/"

func assert_golden(snapshot_name: String, current_data: Dictionary, update_golden: bool = false) -> bool:
	var path = GOLDEN_DIR + snapshot_name + ".json"
	
	if update_golden or not FileAccess.file_exists(path):
		var dir = DirAccess.open("res://")
		if not dir.dir_exists("tests/regression/golden"):
			dir.make_dir_recursive("tests/regression/golden")
		
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			fail("Failed to write golden file: " + path)
			return false
		file.store_string(JSON.stringify(current_data, "  "))
		file.close()
		print("  [GOLDEN UPDATED] Saved snapshot to: %s" % path)
		return true

	var read_file = FileAccess.open(path, FileAccess.READ)
	if read_file == null:
		fail("Failed to read golden file: " + path)
		return false
	
	var content = read_file.get_as_text()
	read_file.close()
	
	var json = JSON.new()
	var parse_err = json.parse(content)
	if parse_err != OK:
		fail("Failed to parse golden file %s: %s" % [path, json.get_error_message()])
		return false
	
	var golden_data = json.data
	if not (golden_data is Dictionary):
		fail("Golden data in %s is not a dictionary" % path)
		return false
	
	var mismatches: Array[String] = []
	_compare_dicts("", current_data, golden_data, mismatches)
			
	if mismatches.size() > 0:
		fail("Regression snapshot mismatch for '%s':\n    %s" % [snapshot_name, "\n    ".join(mismatches)])
		return false
		
	return true

func _compare_dicts(prefix: String, current: Dictionary, golden: Dictionary, mismatches: Array[String]) -> void:
	for k in golden.keys():
		var full_k = (prefix + "." + str(k)) if prefix != "" else str(k)
		if not current.has(k):
			mismatches.append("Missing key in current: %s" % full_k)
		else:
			var cur_v = current[k]
			var gold_v = golden[k]
			if cur_v is Dictionary and gold_v is Dictionary:
				_compare_dicts(full_k, cur_v, gold_v, mismatches)
			elif not _values_match(cur_v, gold_v):
				mismatches.append("Key '%s' mismatch: golden='%s' vs current='%s'" % [full_k, str(gold_v), str(cur_v)])

	for k in current.keys():
		var full_k = (prefix + "." + str(k)) if prefix != "" else str(k)
		if not golden.has(k):
			mismatches.append("Extra key in current: %s" % full_k)

func _values_match(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) < 0.0001
	return str(a) == str(b)

static func hash_bytes(data: PackedByteArray) -> String:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(data)
	var digest = ctx.finish()
	return digest.hex_encode()

static func hash_int_array(arr: PackedInt32Array) -> String:
	return hash_bytes(arr.to_byte_array())

static func hash_float_array(arr: PackedFloat32Array) -> String:
	return hash_bytes(arr.to_byte_array())
