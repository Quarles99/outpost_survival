extends CanvasLayer
class_name HUD

signal build_pressed

const COUNT_DURATION := 0.35
const PUNCH_SCALE := Vector2(1.15, 1.15)

@onready var food_label: Label = $Control/FoodLabel
@onready var wood_label: Label = $Control/WoodLabel
@onready var stone_label: Label = $Control/StoneLabel
@onready var water_label: Label = $Control/WaterLabel
@onready var population_label: Label = $Control/PopulationLabel
@onready var happiness_label: Label = $Control/HappinessLabel
@onready var build_button: Button = $Control/BuildButton
@onready var save_indicator: Label = $SaveIndicator

const RATE_REFRESH_INTERVAL := 1.0

var _resource_labels: Dictionary = {}
var _displayed := {"food": 0.0, "wood": 0.0, "stone": 0.0}
var _count_tweens := {}
var _save_indicator_tween: Tween
var _rate_timer: Timer


func _ready() -> void:
	_resource_labels = {"food": food_label, "wood": wood_label, "stone": stone_label}
	food_label.resized.connect(func() -> void: food_label.pivot_offset = food_label.size / 2)
	wood_label.resized.connect(func() -> void: wood_label.pivot_offset = wood_label.size / 2)
	stone_label.resized.connect(func() -> void: stone_label.pivot_offset = stone_label.size / 2)
	water_label.resized.connect(func() -> void: water_label.pivot_offset = water_label.size / 2)
	population_label.resized.connect(func() -> void: population_label.pivot_offset = population_label.size / 2)
	happiness_label.resized.connect(func() -> void: happiness_label.pivot_offset = happiness_label.size / 2)
	GameState.resources_changed.connect(_on_resources_changed)
	GameState.population_changed.connect(_on_population_changed)
	GameState.water_changed.connect(_on_water_changed)
	GameState.storage_capacity_changed.connect(_on_storage_capacity_changed)
	build_button.pressed.connect(func() -> void: build_pressed.emit())
	for resource_name in _resource_labels:
		_set_display(resource_name, GameState.resources[resource_name])
	_set_population(GameState.population_count, GameState.population_capacity)
	_set_water(GameState.has_water())
	save_indicator.modulate.a = 0.0

	_rate_timer = Timer.new()
	_rate_timer.wait_time = RATE_REFRESH_INTERVAL
	_rate_timer.timeout.connect(_refresh_rates)
	add_child(_rate_timer)
	_rate_timer.start()


## Transient status text (e.g. "Saved"/"Loaded") - fades in, holds, fades out.
func flash_message(text: String) -> void:
	if _save_indicator_tween:
		_save_indicator_tween.kill()
	save_indicator.text = text
	save_indicator.modulate.a = 1.0
	_save_indicator_tween = create_tween()
	_save_indicator_tween.tween_interval(1.0)
	_save_indicator_tween.tween_property(save_indicator, "modulate:a", 0.0, 0.4)


## Alternative Crop Types added several resource types (grain, flour, hops,
## beer...) that don't have a HUD row - showing everything would make this
## compact corner panel unreasonably tall, so only the ones in
## _resource_labels are surfaced here (see Implement_Next.txt). This handler
## is wired to every resource change though, not just displayed ones, so it
## has to ignore anything it doesn't have a label for rather than assume one
## exists.
func _on_resources_changed(resource_name: String, total: float) -> void:
	if not _resource_labels.has(resource_name):
		return
	if _count_tweens.has(resource_name) and _count_tweens[resource_name]:
		_count_tweens[resource_name].kill()

	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _set_display(resource_name, v), _displayed[resource_name], total, COUNT_DURATION).set_ease(Tween.EASE_OUT)
	_count_tweens[resource_name] = tween

	_punch(resource_name)


func _set_display(resource_name: String, value: float) -> void:
	_displayed[resource_name] = value
	_update_label_text(resource_name)


## Rebuilds a resource label's full text (amount + rate) without touching
## _displayed - called both when the amount changes (_set_display) and on
## the independent per-second rate refresh, so the rate updates smoothly
## even while the amount itself is momentarily unchanged.
func _update_label_text(resource_name: String) -> void:
	var label: Label = _resource_labels.get(resource_name)
	if not label:
		return
	var value: float = _displayed[resource_name]
	var rate := GameState.get_income_per_minute(resource_name)
	label.text = "%s: %d/%d (%s%.1f/min)" % [resource_name.capitalize(), value, GameState.storage_capacity, "+" if rate >= 0.0 else "", rate]


func _refresh_rates() -> void:
	for resource_name in _resource_labels:
		_update_label_text(resource_name)


func _punch(resource_name: String) -> void:
	var label: Label = _resource_labels.get(resource_name)
	if not label:
		return
	label.scale = PUNCH_SCALE
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)


func _on_population_changed(count: int, capacity: int) -> void:
	_set_population(count, capacity)
	population_label.scale = PUNCH_SCALE
	var tween := create_tween()
	tween.tween_property(population_label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)


func _set_population(count: int, capacity: int) -> void:
	population_label.text = "Population: %d/%d" % [count, capacity]


func _on_water_changed(available: bool) -> void:
	_set_water(available)
	water_label.scale = PUNCH_SCALE
	var tween := create_tween()
	tween.tween_property(water_label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)


func _set_water(available: bool) -> void:
	water_label.text = "Water: Available" if available else "Water: None"


## Capacity applies to every resource, so a change (a new Storage Facility)
## needs to refresh all the labels, not just one - unlike _on_resources_changed
## there's no single resource_name to key off of.
func _on_storage_capacity_changed(_capacity: float) -> void:
	for resource_name in _resource_labels:
		_set_display(resource_name, _displayed[resource_name])


## Called directly by Base after each happiness tick, rather than through a
## GameState signal - the average is computed from the character roster,
## which Base owns and GameState has no reference to (same reasoning as
## flash_message being a direct call rather than a signal). `band_name` is
## whichever of Base.HAPPINESS_BANDS the average currently falls into
## ("Thriving"/"Content"/"Unhappy"/"Miserable") - shown so the production
## bonus/debuff that band applies isn't invisible to the player.
func set_happiness(average: float, band_name: String) -> void:
	happiness_label.text = "Happiness: %d%% (%s)" % [roundi(average), band_name]
	happiness_label.scale = PUNCH_SCALE
	var tween := create_tween()
	tween.tween_property(happiness_label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)
