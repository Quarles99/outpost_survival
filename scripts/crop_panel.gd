extends CanvasLayer
class_name CropPanel

signal option_selected(option: Dictionary)
## Reported back to Base the same way CitizensPanel.citizen_selected/
## BuildingInfoPanel.employee_selected are - a click on the "who's working
## here" row below the crop grid, letting the player select that citizen
## (opens their SkillPanel) without leaving this panel implicitly tied to
## the click.
signal employee_selected(character: Character)

const SLIDE_OFFSET := Vector2(0, 20)
const ANIM_DURATION := 0.18
const ICON_SIZE := Vector2(64, 64)
const LABEL_FONT_SIZE := 13
const BACKGROUND_DARKEN := 0.35
const DEFAULT_BACKGROUND := Color(0.22, 0.24, 0.28)

@onready var panel_control: Control = $Control
@onready var title_label: Label = $Control/Panel/VBoxContainer/TitleLabel
@onready var description_label: Label = $Control/Panel/VBoxContainer/DescriptionLabel
@onready var button_container: GridContainer = $Control/Panel/VBoxContainer/ButtonContainer
@onready var employee_container: VBoxContainer = $Control/Panel/VBoxContainer/EmployeeContainer

var _buttons: Array[Button] = []
var _employee_rows: Array[Control] = []
var _option_callables: Array[Callable] = []
var _base_position: Vector2
var _anim_tween: Tween

## Shares BuildMenu's text-on-color square button design (see its own doc
## comment on _add_button for why - shrunk-down in-world sprites read as an
## illegible smudge, especially since most Farm-family buildings share one
## generic silhouette differing only by tint) but is otherwise a separate
## class rather than a second mode bolted onto BuildMenu - retooling an
## already-placed building is a meaningfully different action (free,
## instant, no ghost/placement flow) from placing a new one. See
## RecruitPanel for the same "near-exact clone for a different purpose"
## precedent.


func _ready() -> void:
	visible = false
	_base_position = panel_control.position


## `target_display_name` names the building being retooled (e.g. "Farm"),
## shown in the title so it's clear this reconfigures that specific
## building rather than placing a new one. `employees` - who currently
## works this specific Farm (see Base._employees_of) - Farm-family posts
## cap at 1 worker (Workstation's own max_workers default), so this is
## always a single row or the empty state, never a scrollable list the way
## TrainingGroundPanel's needs to be.
func open_for(options: Array, target_display_name: String, employees: Array[Character] = [], description: String = "") -> void:
	title_label.text = "Change Crop: %s" % target_display_name
	description_label.visible = not description.is_empty()
	description_label.text = description
	_clear_buttons()
	_option_callables.clear()
	_rebuild_employees(employees)

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


func _choose_employee(character: Character) -> void:
	employee_selected.emit(character)
	close()


## "Worked by: <name>" (clickable, selects them) or "Vacant" - see
## open_for's own doc comment for why this is always at most one row.
func _rebuild_employees(employees: Array[Character]) -> void:
	for row in _employee_rows:
		row.queue_free()
	_employee_rows.clear()

	if employees.is_empty():
		var label := Label.new()
		label.text = "Vacant"
		label.modulate.a = 0.6
		employee_container.add_child(label)
		_employee_rows.append(label)
		return

	for character in employees:
		var name_text: String = character.data.character_name if character.data else "Unknown"
		var button := Button.new()
		button.text = "Worked by: %s" % name_text
		button.pressed.connect(func() -> void: _choose_employee(character))
		employee_container.add_child(button)
		_employee_rows.append(button)


## See BuildMenu._short_name - identical derivation, kept as a separate copy
## since the two panels have no other coupling.
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


func _add_button(option: Dictionary, keybind: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = ICON_SIZE
	button.clip_contents = true
	button.tooltip_text = option["display_name"]
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
