extends Node
## Fixture for saved data: round-trips a value, then plants a corrupt save
## file and reloads. The game must keep running, move the bad file aside and
## start from defaults. Results go to the verification log as fixture_result.

func _ready() -> void:
	var r := {}
	Save.write("fixture_value", 42)
	r["flush"] = Save.flush()
	Save._data = {}
	Save._load()
	r["round_trip"] = Save.read("fixture_value") == 42
	var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	Save._load()
	r["corrupt_handled"] = Save.read("fixture_value") == null and Save.last_error.contains("corrupt")
	var aside := 0
	for n in DirAccess.get_files_at("user://"):
		if n.begins_with("save.json.corrupt-"):
			aside += 1
	r["moved_aside"] = aside >= 1
	r["pass"] = r["flush"] == OK and r["round_trip"] and r["corrupt_handled"] and r["moved_aside"]
	get_node("/root/Verify").fixture_result = r
