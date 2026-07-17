extends CanvasLayer
class_name TrainingGroundPanel

## A built Barracks/Archery Range/Mage Tower's `clicked` signal used to mean
## one fixed thing ("open a single-candidate recruit panel"). Now that the
## same building also offers a repeatable Upgrade (see TrainingGround's own
## doc comment on upgrade_level/get_unit_cap), clicking needs to offer a
## choice between the two instead of jumping straight to either - this panel
## is that intermediate choice. Exact same open/close tween + numbered-
## shortcut mechanics as RecruitPanel/CropPanel (see their own doc
## comments) - a third instance of the same "numbered option picker"
## convention rather than a new one.
signal option_chosen(option_id: String)

const SLIDE_OFFSET := Vector2(0, 20)
const ANIM_DURATION := 0.18

@onready var panel_control: Control = $Control
@onready var title_label: Label = $Control/Panel/VBoxContainer/TitleLabel
@onready var button_container: VBoxContainer = $Control/Panel/VBoxContainer/ButtonContainer

var _buttons: Array[Button] = []
var _option_callables: Array[Callable] = []
var _base_position: Vector2
var _anim_tween: Tween


func _ready() -> void:
	visible = false
	_base_position = panel_control.position


## Each option: {"id": String, "label": String, "enabled": bool (default
## true)}. A disabled option (currently just "Recruit" while on cooldown)
## still shows with its own numbered shortcut, but neither the button nor
## the shortcut can trigger it - reads as "not right now" rather than
## vanishing outright, same reasoning CropPanel/RecruitPanel don't need
## since every option they list is always choosable.
func open_for(building_name: String, options: Array[Dictionary]) -> void:
	title_label.text = building_name
	_clear_buttons()
	_option_callables.clear()

	for i in options.size():
		var option: Dictionary = options[i]
		var enabled: bool = option.get("enabled", true)
		var prefix := "[%d] " % (i + 1) if i < 9 else ""
		var callable := func() -> void: _choose(option["id"])
		_add_button(prefix + String(option["label"]), callable, enabled)
		_option_callables.append(callable if enabled else func() -> void: pass)

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


func _choose(option_id: String) -> void:
	option_chosen.emit(option_id)
	close()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = int(event.keycode) - int(KEY_1)
		if idx >= 0 and idx < _option_callables.size():
			get_viewport().set_input_as_handled()
			_option_callables[idx].call()


func _add_button(text: String, on_pressed: Callable, enabled: bool) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
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
