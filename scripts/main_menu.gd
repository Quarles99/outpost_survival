extends Control
class_name MainMenu

const BASE_SCENE := "res://scenes/base/Base.tscn"
const COMBAT_TEST_SCENE := "res://scenes/combat/CombatTest.tscn"

@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var new_game_button: Button = $CenterContainer/VBoxContainer/NewGameButton
@onready var load_game_button: Button = $CenterContainer/VBoxContainer/LoadGameButton
@onready var battle_test_button: Button = $CenterContainer/VBoxContainer/BattleTestButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var slot_panel: SlotPanel = $SlotPanel

## Which button opened slot_panel - "new" or "load" - so _on_slot_chosen
## knows whether the picked slot should be loaded or started fresh.
## SlotPanel itself has no opinion on this; it just reports the slot back.
var _pending_mode := ""


func _ready() -> void:
	var any_save := SaveManager.has_any_save()
	continue_button.disabled = not any_save
	load_game_button.disabled = not any_save

	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(func() -> void: _open_slot_panel("new"))
	load_game_button.pressed.connect(func() -> void: _open_slot_panel("load"))
	battle_test_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(COMBAT_TEST_SCENE))
	quit_button.pressed.connect(func() -> void: get_tree().quit())

	slot_panel.slot_chosen.connect(_on_slot_chosen)


## Shortcut past the slot picker entirely - loads whichever slot has the
## newest "saved_at" timestamp, for the common case of "just get me back
## into my game" without making the player remember which slot that was.
func _on_continue_pressed() -> void:
	var slot := SaveManager.most_recent_slot()
	if slot == -1:
		return
	_start_game(slot, true)


func _open_slot_panel(mode: String) -> void:
	_pending_mode = mode
	slot_panel.open_for(mode)


func _on_slot_chosen(slot: int) -> void:
	_start_game(slot, _pending_mode == "load")


func _start_game(slot: int, should_load: bool) -> void:
	SaveManager.active_slot = slot
	SaveManager.should_load_on_start = should_load
	get_tree().change_scene_to_file(BASE_SCENE)
