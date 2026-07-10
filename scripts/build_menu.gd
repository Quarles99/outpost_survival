extends CanvasLayer
class_name BuildMenu

signal option_selected(option: Dictionary)

const SLIDE_OFFSET := Vector2(0, 20)
const ANIM_DURATION := 0.18
const ICON_SIZE := Vector2(64, 64)
const LABEL_FONT_SIZE := 13
## Darkens a building's sprite_tint before using it as a button's background,
## so white text stays legible on top regardless of how light the tint
## itself is (several crop-chain tints - e.g. Mill's near-white
## (0.8, 0.78, 0.72) - would otherwise wash out white text almost entirely).
const BACKGROUND_DARKEN := 0.35
## Background for anything with no custom sprite_tint (Color.WHITE, the
## Workstation default) - most non-crop buildings fall here. A flat neutral
## rather than white-darkened-by-BACKGROUND_DARKEN so it doesn't just read
## as "generic gray version of every tinted button."
const DEFAULT_BACKGROUND := Color(0.22, 0.24, 0.28)

@onready var panel_control: Control = $Control
@onready var title_label: Label = $Control/Panel/VBoxContainer/TitleLabel
@onready var button_container: GridContainer = $Control/Panel/VBoxContainer/ButtonContainer

var _buttons: Array[Button] = []
var _option_callables: Array[Callable] = []
var _base_position: Vector2
var _anim_tween: Tween


func _ready() -> void:
	visible = false
	_base_position = panel_control.position


func open_for(options: Array) -> void:
	title_label.text = "Build"
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


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts: Array[String] = []
	for resource_name in cost:
		parts.append("%d %s" % [int(cost[resource_name]), String(resource_name).capitalize()])
	return " (%s)" % ", ".join(parts)


## The first word of a building's display_name ("Grain Farm" -> "Grain",
## "Stone Mine" -> "Stone") - short enough to read at a glance inside a
## small square, and happens to be the more distinctive word in every
## current two-word name (checked against all 14 catalog entries; if a
## future addition collides, this would need a dedicated short-name field
## instead of deriving one).
func _short_name(display_name: String) -> String:
	return display_name.split(" ")[0]


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = int(event.keycode) - int(KEY_1)
		if idx >= 0 and idx < _option_callables.size():
			get_viewport().set_input_as_handled()
			_option_callables[idx].call()


## Square buttons used to show each building's actual in-world sprite
## shrunk down, but most buildings share one generic silhouette texture
## (see CLAUDE.md/BuildingCatalog - 9 of today's 14 only differ by tint),
## and even the buildings with distinct art were drawn for a zoomed-in
## world view, not a 64px button - both read as an illegible, near-
## identical smudge at this size. A bold, self-contained name is the one
## thing guaranteed to actually identify the building at a glance, so
## that's now the button's entire content - the tooltip (full name + cost)
## is a supplement, not a requirement, for figuring out what it is.
func _add_button(option: Dictionary, keybind: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = ICON_SIZE
	button.clip_contents = true
	button.tooltip_text = option["display_name"] + _format_cost(option.get("cost", {}))
	button.pressed.connect(on_pressed)
	button.resized.connect(func() -> void: button.pivot_offset = button.size / 2)
	button.button_down.connect(func() -> void: button.scale = Vector2(0.94, 0.94))
	button.button_up.connect(func() -> void:
		var tween := create_tween()
		tween.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

	var tint: Color = option.get("sprite_tint", Color.WHITE)
	var background := DEFAULT_BACKGROUND if tint == Color.WHITE else tint.darkened(BACKGROUND_DARKEN)
	var background_rect := ColorRect.new()
	background_rect.color = background
	background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(background_rect)

	var name_label := Label.new()
	name_label.text = _short_name(option["display_name"])
	name_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_label.offset_left += 2
	name_label.offset_right -= 2
	button.add_child(name_label)

	if not keybind.is_empty():
		var keybind_label := Label.new()
		keybind_label.text = keybind
		keybind_label.add_theme_font_size_override("font_size", 12)
		keybind_label.add_theme_color_override("font_color", Color.WHITE)
		keybind_label.add_theme_constant_override("outline_size", 3)
		keybind_label.add_theme_color_override("font_outline_color", Color.BLACK)
		keybind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		keybind_label.position = Vector2(4, 2)
		button.add_child(keybind_label)

	button_container.add_child(button)
	_buttons.append(button)


func _clear_buttons() -> void:
	for button in _buttons:
		button.queue_free()
	_buttons.clear()
