extends CanvasLayer
class_name SlotPanel

## Emitted when the player picks a slot to act on - what "acting on it"
## means (start a new game there, load it, save into it) is entirely up to
## whoever called open_for() and is listening for this; SlotPanel itself
## just presents SaveManager's slots and reports back which one was chosen.
signal slot_chosen(slot: int)

const SLIDE_OFFSET := Vector2(0, 20)
const ANIM_DURATION := 0.18

@onready var panel_control: Control = $Control
@onready var title_label: Label = $Control/Panel/VBoxContainer/TitleLabel
@onready var slot_container: VBoxContainer = $Control/Panel/VBoxContainer/SlotContainer
@onready var cancel_button: Button = $Control/Panel/VBoxContainer/CancelButton

var _base_position: Vector2
var _anim_tween: Tween
var _slot_buttons: Array[Button] = []

## Which action open_for() was last called with - purely cosmetic (title
## text, and which slots are clickable), never interpreted by SlotPanel
## itself beyond that.
var _mode := "load"


func _ready() -> void:
	visible = false
	_base_position = panel_control.position
	cancel_button.pressed.connect(close)


## `mode` is "new" (start a fresh game in the chosen slot - every slot is
## clickable, an occupied one just says it'll be overwritten), "load" (only
## occupied slots are clickable), or "save" (every slot is clickable, same
## overwrite note as "new").
func open_for(mode: String) -> void:
	_mode = mode
	title_label.text = {"new": "New Game", "load": "Load Game", "save": "Save Game"}.get(mode, "Select Slot")
	_rebuild_slots()

	visible = true
	panel_control.position = _base_position + SLIDE_OFFSET
	panel_control.modulate.a = 0.0

	if _anim_tween:
		_anim_tween.kill()
	_anim_tween = create_tween().set_parallel()
	_anim_tween.tween_property(panel_control, "position", _base_position, ANIM_DURATION).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(panel_control, "modulate:a", 1.0, ANIM_DURATION)


func close() -> void:
	if not visible:
		return
	if _anim_tween:
		_anim_tween.kill()
	_anim_tween = create_tween().set_parallel()
	_anim_tween.tween_property(panel_control, "position", _base_position + SLIDE_OFFSET, ANIM_DURATION).set_ease(Tween.EASE_IN)
	_anim_tween.tween_property(panel_control, "modulate:a", 0.0, ANIM_DURATION)
	_anim_tween.chain().tween_callback(func() -> void: visible = false)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = int(event.keycode) - int(KEY_1)
		if idx >= 0 and idx < _slot_buttons.size() and not _slot_buttons[idx].disabled:
			get_viewport().set_input_as_handled()
			_choose(idx + 1)


func _rebuild_slots() -> void:
	for button in _slot_buttons:
		button.queue_free()
	_slot_buttons.clear()

	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var button := Button.new()
		button.text = "[%d] %s" % [slot, _slot_summary(slot)]
		button.disabled = _mode == "load" and not SaveManager.has_save(slot)
		button.pressed.connect(_choose.bind(slot))
		slot_container.add_child(button)
		_slot_buttons.append(button)


## "Slot 1: Empty", or "Slot 1: 2026-07-10 14:32 - Pop 4" for an occupied
## one - read straight off the full saved dict (SaveManager.load_game())
## rather than a dedicated summary API, since a save file is tiny JSON and
## this only runs when the panel opens, not every frame.
func _slot_summary(slot: int) -> String:
	if not SaveManager.has_save(slot):
		return "Slot %d: Empty" % slot
	var data := SaveManager.load_game(slot)
	var saved_at: String = Time.get_datetime_string_from_unix_time(int(data.get("saved_at", 0)), true)
	var population: int = int(data.get("population_count", 0))
	return "Slot %d: %s - Pop %d" % [slot, saved_at, population]


func _choose(slot: int) -> void:
	slot_chosen.emit(slot)
	close()
