extends CanvasLayer
class_name SystemMenu

## Resume has nothing for Base to act on beyond closing this menu, so it's
## just a button wired straight to close() (see _ready) rather than a
## fifth signal Base would only ever respond to with close_system_menu().
signal save_pressed
signal load_pressed
signal main_menu_pressed
signal quit_pressed

const SLIDE_OFFSET := Vector2(0, 20)
const ANIM_DURATION := 0.18

@onready var panel_control: Control = $Control
@onready var resume_button: Button = $Control/Panel/VBoxContainer/ResumeButton
@onready var save_button: Button = $Control/Panel/VBoxContainer/SaveButton
@onready var load_button: Button = $Control/Panel/VBoxContainer/LoadButton
@onready var main_menu_button: Button = $Control/Panel/VBoxContainer/MainMenuButton
@onready var quit_button: Button = $Control/Panel/VBoxContainer/QuitButton

var _base_position: Vector2
var _anim_tween: Tween


func _ready() -> void:
	visible = false
	_base_position = panel_control.position

	resume_button.pressed.connect(close)
	save_button.pressed.connect(func() -> void:
		save_pressed.emit()
		close()
	)
	load_button.pressed.connect(func() -> void:
		load_pressed.emit()
		close()
	)
	main_menu_button.pressed.connect(func() -> void:
		main_menu_pressed.emit()
		close()
	)
	quit_button.pressed.connect(func() -> void:
		quit_pressed.emit()
		close()
	)


func open() -> void:
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
