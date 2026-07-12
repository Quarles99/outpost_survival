extends CanvasLayer
class_name RecruitPanel

signal candidate_selected(candidate: Dictionary)

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


func open_for(candidates: Array[Dictionary]) -> void:
	title_label.text = "Recruit"
	_clear_buttons()
	_option_callables.clear()

	for i in candidates.size():
		var candidate: Dictionary = candidates[i]
		var prefix := "[%d] " % (i + 1) if i < 9 else ""
		var callable := func() -> void: _choose(candidate)
		var label := "%s%s (Lv %d %s)\n%s" % [prefix, candidate["name"], candidate["level"], candidate["skill_label"], _cost_text(candidate["cost"])]
		_add_button(label, callable)
		_option_callables.append(callable)

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


func _choose(candidate: Dictionary) -> void:
	candidate_selected.emit(candidate)
	close()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = int(event.keycode) - int(KEY_1)
		if idx >= 0 and idx < _option_callables.size():
			get_viewport().set_input_as_handled()
			_option_callables[idx].call()


## "15 Cabbage + 15 Ale" - cost dict iterates in insertion order, which
## RecruitCatalog._cost_for_tier builds low-tier-first, so this always
## reads as an ascending list without needing to sort here. Reuses HUD's
## display-label map so "beer" reads as "Ale" here too, rather than
## drifting from what the Food breakdown panel calls it.
func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_name in cost:
		var label: String = HUD.FOOD_BREAKDOWN_LABELS.get(resource_name, resource_name.capitalize())
		parts.append("%d %s" % [int(cost[resource_name]), label])
	return " + ".join(parts)


func _add_button(text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	## A candidate's cost line can run long at high food tiers (up to all 5
	## food types listed) - word-wrap rather than letting it overflow the
	## button/panel width or silently clip.
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
