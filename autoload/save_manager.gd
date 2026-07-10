extends Node

## Local JSON save files, one per slot. Cloud sync is a future concern -
## this just owns the raw read/write; Base is responsible for building/
## applying the state dict (SaveManager doesn't know or care what's in it,
## beyond the couple of fields the slot-picker UI reads directly off the
## dict it returns - see slot_panel.gd).
const SAVE_DIR := "user://saves/"
const SLOT_COUNT := 3

## Which slot F5/F9 and the in-game Save/Load menu act on - set once by
## MainMenu (or the in-game slot picker) before switching into Base.tscn.
## Defaults to 1 so a save/load still works sensibly even if something
## reaches Base.tscn without going through MainMenu first (e.g. running the
## scene directly from the editor during development).
var active_slot: int = 1

## Consumed exactly once by Base._ready() - true means "apply active_slot's
## save on top of the fresh scene," false means "start clean." Reset to
## false immediately after Base reads it, so a later F9/in-game load
## doesn't re-trigger this on some future scene reload.
var should_load_on_start: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_migrate_legacy_save()


## Pre-slot-system saves lived at a single fixed path - if one of those
## exists and slot 1 hasn't been written to yet under the new scheme,
## move it into slot 1 rather than stranding it unreadable. One-time; does
## nothing once migrated (or if there was never a legacy save).
func _migrate_legacy_save() -> void:
	const LEGACY_PATH := "user://savegame.json"
	if not FileAccess.file_exists(LEGACY_PATH):
		return
	if has_save(1):
		return
	var err := DirAccess.rename_absolute(LEGACY_PATH, _slot_path(1))
	if err != OK:
		push_error("SaveManager: failed to migrate legacy save (error %d)" % err)


func _slot_path(slot: int) -> String:
	return "%sslot_%d.json" % [SAVE_DIR, slot]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


## True if any slot has a save - used to enable/disable MainMenu's
## "Continue" button without needing to know which slot is most recent.
func has_any_save() -> bool:
	for slot in range(1, SLOT_COUNT + 1):
		if has_save(slot):
			return true
	return false


## The slot with the most recent "saved_at" timestamp, or -1 if no slot has
## a save - what MainMenu's "Continue" loads directly, without making the
## player pick a slot themselves.
func most_recent_slot() -> int:
	var best_slot := -1
	var best_time := -1
	for slot in range(1, SLOT_COUNT + 1):
		if not has_save(slot):
			continue
		var saved_at: int = int(load_game(slot).get("saved_at", 0))
		if saved_at > best_time:
			best_time = saved_at
			best_slot = slot
	return best_slot


## Writes to a temp file and renames over the slot's path so a crash/disk-
## full mid-write can't leave a truncated save behind - the old good save
## (if any) is only replaced once the new one has been fully written to disk.
func save_game(slot: int, data: Dictionary) -> void:
	var path := _slot_path(slot)
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: failed to open '%s' for writing" % tmp_path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		push_error("SaveManager: failed to replace '%s' with new save (error %d)" % [path, err])


## Returns {} if that slot has no save file or it fails to parse.
func load_game(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not has_save(slot):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("SaveManager: failed to open '%s' for reading" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: '%s' is corrupt or not a JSON object" % path)
		return {}
	return parsed


func delete_save(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
