extends CanvasLayer
class_name CropPanel

signal option_selected(option: Dictionary)

const SLIDE_OFFSET := Vector2(0, 20)
const ANIM_DURATION := 0.18
const ICON_SIZE := Vector2(64, 64)

@onready var panel_control: Control = $Control
@onready var title_label: Label = $Control/Panel/VBoxContainer/TitleLabel
@onready var button_container: GridContainer = $Control/Panel/VBoxContainer/ButtonContainer

var _buttons: Array[Button] = []
var _option_callables: Array[Callable] = []
var _base_position: Vector2
var _anim_tween: Tween

## Shares BuildMenu's icon-grid look (and its _get_icon_data approach) but
## is otherwise a separate class rather than a second mode bolted onto
## BuildMenu - retooling an already-placed building is a meaningfully
## different action (free, instant, no ghost/placement flow) from placing
## a new one, and the two panels shouldn't need to agree on one option's
## worth of behavior just because they look alike. See RecruitPanel for the
## same "near-exact clone for a different purpose" precedent.
var _icon_cache: Dictionary = {}


func _ready() -> void:
	visible = false
	_base_position = panel_control.position


## `target_display_name` names the building being retooled (e.g. "Farm"),
## shown in the title so it's clear this reconfigures that specific
## building rather than placing a new one.
func open_for(options: Array, target_display_name: String) -> void:
	title_label.text = "Change Crop: %s" % target_display_name
	_clear_buttons()
	_option_callables.clear()

	for i in options.size():
		var option: Dictionary = options[i]
		var keybind := "%d" % (i + 1) if i < 9 else ""
		var callable := func() -> void: _choose(option)
		_add_button(option, keybind, callable)
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


func _choose(option: Dictionary) -> void:
	option_selected.emit(option)
	close()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = int(event.keycode) - int(KEY_1)
		if idx >= 0 and idx < _option_callables.size():
			get_viewport().set_input_as_handled()
			_option_callables[idx].call()


func _add_button(option: Dictionary, keybind: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = ICON_SIZE
	button.tooltip_text = option["display_name"]
	button.pressed.connect(on_pressed)
	button.resized.connect(func() -> void: button.pivot_offset = button.size / 2)
	button.button_down.connect(func() -> void: button.scale = Vector2(0.94, 0.94))
	button.button_up.connect(func() -> void:
		var tween := create_tween()
		tween.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

	var icon_data := _get_icon_data(option)
	if icon_data.get("texture"):
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_data["texture"]
		icon_rect.modulate = icon_data["modulate"]
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.add_child(icon_rect)

	if not keybind.is_empty():
		var keybind_label := Label.new()
		keybind_label.text = keybind
		keybind_label.add_theme_font_size_override("font_size", 12)
		keybind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		keybind_label.position = Vector2(4, 2)
		button.add_child(keybind_label)

	button_container.add_child(button)
	_buttons.append(button)


## See BuildMenu._get_icon_data - same throwaway-instance approach, kept as
## a separate copy rather than a shared helper since the two panels have no
## other coupling and this is the only thing they'd share.
func _get_icon_data(option: Dictionary) -> Dictionary:
	var id: String = option["id"]
	if _icon_cache.has(id):
		return _icon_cache[id]

	var data := {"texture": null, "modulate": Color.WHITE}
	var instance: Node2D = option["scene"].instantiate()
	for key in Base.BUILDING_PROPERTIES:
		if option.has(key):
			instance.set(key, option[key])
	instance.visible = false
	add_child(instance)
	if instance.has_node("Sprite2D"):
		var sprite: Sprite2D = instance.get_node("Sprite2D")
		data["texture"] = sprite.texture
		data["modulate"] = sprite.modulate
	instance.queue_free()

	_icon_cache[id] = data
	return data


func _clear_buttons() -> void:
	for button in _buttons:
		button.queue_free()
	_buttons.clear()
