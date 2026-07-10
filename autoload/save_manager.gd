extends Node

## Local JSON save file. Cloud sync is a future concern - this just owns the
## raw read/write; Base is responsible for building/applying the state dict.
const SAVE_PATH := "user://savegame.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Writes to a temp file and renames over SAVE_PATH so a crash/disk-full
## mid-write can't leave a truncated save behind - the old good save (if any)
## is only replaced once the new one has been fully written to disk.
func save_game(data: Dictionary) -> void:
	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: failed to open '%s' for writing" % tmp_path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(tmp_path, SAVE_PATH)
	if err != OK:
		push_error("SaveManager: failed to replace '%s' with new save (error %d)" % [SAVE_PATH, err])


## Returns {} if there's no save file or it fails to parse.
func load_game() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("SaveManager: failed to open '%s' for reading" % SAVE_PATH)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: '%s' is corrupt or not a JSON object" % SAVE_PATH)
		return {}
	return parsed
