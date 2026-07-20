extends CanvasLayer
class_name BuildingInfoPanel

## Opens on left-clicking a plain job post (LumberCamp/StoneMine/
## Brickmaker/Workshop/ConstructionSite - see Base._wire_building_info_
## clicks) or a House (see Base._on_house_clicked) - Farm/TrainingGround
## show this same name+employees info inside their own existing panels
## instead (CropPanel/TrainingGroundPanel), so this one is never opened for
## those. Base decides what a click means (same philosophy as
## Character.clicked/CitizensPanel.citizen_selected) - this just reports
## which employee row was pressed; Base reuses its existing
## _on_character_selected() (open the skill panel, same as clicking them
## in-world).
signal employee_selected(character: Character)

const SLIDE_OFFSET := Vector2(0, 20)
const ANIM_DURATION := 0.18

@onready var panel_control: Control = $Control
@onready var title_label: Label = $Control/Margin/VBoxContainer/TitleLabel
@onready var description_label: Label = $Control/Margin/VBoxContainer/DescriptionLabel
@onready var recipe_label: Label = $Control/Margin/VBoxContainer/RecipeLabel
@onready var upgrade_button: Button = $Control/Margin/VBoxContainer/UpgradeButton
@onready var worker_count_row: HBoxContainer = $Control/Margin/VBoxContainer/WorkerCountRow
@onready var worker_count_label: Label = $Control/Margin/VBoxContainer/WorkerCountRow/WorkerCountLabel
@onready var worker_minus_button: Button = $Control/Margin/VBoxContainer/WorkerCountRow/MinusButton
@onready var worker_plus_button: Button = $Control/Margin/VBoxContainer/WorkerCountRow/PlusButton
@onready var empty_label: Label = $Control/Margin/VBoxContainer/EmptyLabel
@onready var scroll_container: ScrollContainer = $Control/Margin/VBoxContainer/ScrollContainer
@onready var button_container: VBoxContainer = $Control/Margin/VBoxContainer/ScrollContainer/ButtonContainer

var _buttons: Array[Button] = []
var _base_position: Vector2
var _anim_tween: Tween
var _upgrade_pressed_callable: Callable
## Called with +1/-1 - see open_for's worker_count/worker_max/on_worker_delta
## params (Actionable Ideas/Implement the ability to increase or decrease
## the desired amount of workers...md).
var _worker_delta_callable: Callable


func _ready() -> void:
	visible = false
	_base_position = panel_control.position
	upgrade_button.pressed.connect(func() -> void:
		if _upgrade_pressed_callable.is_valid():
			_upgrade_pressed_callable.call()
	)
	worker_minus_button.pressed.connect(func() -> void:
		if _worker_delta_callable.is_valid():
			_worker_delta_callable.call(-1)
	)
	worker_plus_button.pressed.connect(func() -> void:
		if _worker_delta_callable.is_valid():
			_worker_delta_callable.call(1)
	)


## `employees` - the Characters with assigned_post == this building (see
## Base._employees_of) - shown as clickable rows the same way CitizensPanel's
## roster is. Most of these post types cap at 1 worker (Workstation's own
## max_workers default), so this is usually a single row or the empty state.
## `show_employees` is false for a House (see Base._on_house_clicked) -
## it's never a job post, so "No one currently employed here"/an empty
## roster list would be actively misleading rather than just unused.
## `upgrade_label`/`on_upgrade` show a button (e.g. "Upgrade (100 Wood + 50
## Brick)") above the employee section when both are given - House's own
## one-time upgrade uses this; a plain job post with no upgrade path (the
## common case) leaves both empty/invalid and the button stays hidden.
## `worker_count`/`worker_max`/`on_worker_delta` are only meaningful when
## `show_employees` is true (a House, the only show_employees=false caller,
## isn't a job post and has no desired_workers concept) - the +/- stepper
## row is gated on that same flag rather than a redundant extra bool.
func open_for(building_name: String, employees: Array[Character] = [], description: String = "", recipe: String = "", show_employees: bool = true, upgrade_label: String = "", on_upgrade: Callable = Callable(), worker_count: int = 0, worker_max: int = 1, on_worker_delta: Callable = Callable()) -> void:
	title_label.text = building_name
	description_label.visible = not description.is_empty()
	description_label.text = description
	recipe_label.visible = not recipe.is_empty()
	recipe_label.text = recipe
	upgrade_button.visible = not upgrade_label.is_empty() and on_upgrade.is_valid()
	upgrade_button.text = upgrade_label
	_upgrade_pressed_callable = on_upgrade
	worker_count_row.visible = show_employees
	worker_count_label.text = "Workers: %d/%d" % [worker_count, worker_max]
	worker_minus_button.disabled = worker_count <= 0
	worker_plus_button.disabled = worker_count >= worker_max
	_worker_delta_callable = on_worker_delta
	_clear_buttons()

	empty_label.visible = show_employees and employees.is_empty()
	scroll_container.visible = show_employees
	for character in employees:
		var callable := func() -> void: _choose(character)
		var name_text: String = character.data.character_name if character.data else "Unknown"
		_add_button(name_text, callable)

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
	employee_selected.emit(character)
	close()


func _add_button(text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
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
