extends CanvasLayer
class_name TaskPanel

signal task_selected(post: Node)
signal idle_selected

const SLIDE_OFFSET := Vector2(0, 20)
const ANIM_DURATION := 0.18

@onready var panel_control: Control = $Control
@onready var name_label: Label = $Control/Panel/VBoxContainer/NameLabel
@onready var button_container: VBoxContainer = $Control/Panel/VBoxContainer/ButtonContainer
@onready var click_sound: AudioStreamPlayer = $ClickSound

var _buttons: Array[Button] = []
var _option_callables: Array[Callable] = []
var _idle_callable: Callable
var _base_position: Vector2
var _anim_tween: Tween


func _ready() -> void:
	visible = false
	_base_position = panel_control.position


func open_for(character: Character, posts: Array) -> void:
	name_label.text = character.data.character_name if character.data else "Unknown"
	_clear_buttons()
	_option_callables.clear()

	for i in posts.size():
		var post = posts[i]
		var prefix := "[%d] " % (i + 1) if i < 9 else ""
		var callable := func() -> void: task_selected.emit(post)
		_add_button(prefix + "Assign to %s" % post.display_name, callable)
		_option_callables.append(callable)

	_idle_callable = func() -> void: idle_selected.emit()
	_add_button("[0] Idle", _idle_callable)

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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_0:
			get_viewport().set_input_as_handled()
			_idle_callable.call()
			return
		var idx: int = int(event.keycode) - int(KEY_1)
		if idx >= 0 and idx < _option_callables.size():
			get_viewport().set_input_as_handled()
			_option_callables[idx].call()


func _add_button(text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	button.resized.connect(func() -> void: button.pivot_offset = button.size / 2)
	button.button_down.connect(func() -> void:
		button.scale = Vector2(0.94, 0.94)
		click_sound.play()
	)
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
