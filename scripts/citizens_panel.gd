extends CanvasLayer
class_name CitizensPanel

## Base decides what a click means (same philosophy as Character.clicked) -
## this just reports which citizen's row was pressed. Base both re-uses its
## existing _on_character_selected() (open the skill panel, same as
## clicking them in-world) and snaps the camera to them.
signal citizen_selected(character: Character)

const SLIDE_OFFSET := Vector2(0, 20)
const ANIM_DURATION := 0.18

## Deliberately no 1-9 shortcut wiring here, unlike RecruitPanel/CropPanel/
## BuildMenu - those all cap out at a handful of options, but the citizen
## roster can easily grow past 9, where a fixed keyboard shortcut range
## stops meaningfully covering the list. Click (or scroll, see
## ScrollContainer in the scene) only.

@onready var panel_control: Control = $Control
@onready var title_label: Label = $Control/Panel/VBoxContainer/TitleLabel
@onready var button_container: VBoxContainer = $Control/Panel/VBoxContainer/ScrollContainer/ButtonContainer

var _buttons: Array[Button] = []
var _base_position: Vector2
var _anim_tween: Tween


func _ready() -> void:
	visible = false
	_base_position = panel_control.position


## `rows` - one Dictionary per citizen, built by Base (not derived here) so
## this panel stays generic the same way RecruitPanel.open_for()'s
## `candidates` does - "name"/"job"/"happiness_text"/"location" are already
## formatted strings, "character" is the Character to report back via
## citizen_selected. Rebuilt from scratch every open rather than diffed -
## the roster is small and this only runs on a deliberate button press, not
## every frame.
func open_for(rows: Array[Dictionary]) -> void:
	title_label.text = "Citizens (%d)" % rows.size()
	_clear_buttons()

	for row in rows:
		var character: Character = row["character"]
		var callable := func() -> void: _choose(character)
		var label := "%s - %s\n%s - %s" % [row["name"], row["job"], row["location"], row["happiness_text"]]
		_add_button(label, callable)

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


func _choose(character: Character) -> void:
	citizen_selected.emit(character)
	close()


func _add_button(text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(on_pressed)
	button.resized.connect(func() -> void: button.pivot_offset = button.size / 2)
	button.button_down.connect(func() -> void: button.scale = Vector2(0.94, 0.94))
	button.button_up.connect(func() -> void:
		var tween := create_tween()
		tween.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	button_container.add_child(button)
	_buttons.append(button)


func _clear_buttons() -> void:
	for button in _buttons:
		button.queue_free()
	_buttons.clear()
