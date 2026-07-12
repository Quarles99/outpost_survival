extends CanvasLayer
class_name HUD

signal build_pressed
signal menu_pressed

const COUNT_DURATION := 0.35
const PUNCH_SCALE := Vector2(1.15, 1.15)

## Order the collapsible Food row's sub-rows are listed in - every
## GameState.FOOD_RESOURCES entry (edible, counted in the aggregate total)
## followed by grain/flour (tracked per the design ask, but inedible on
## their own - see GameState.FOOD_RESOURCES's doc comment - so excluded from
## the aggregate sum below).
const FOOD_BREAKDOWN_ORDER := ["cabbage", "potato", "fruit", "bread", "beer", "grain", "flour"]
const FOOD_BREAKDOWN_LABELS := {
	"cabbage": "Cabbage",
	"potato": "Potatoes",
	"fruit": "Fruit",
	"bread": "Bread",
	"beer": "Ale",
	"grain": "Wheat",
	"flour": "Flour",
}

@onready var food_button: Button = $Control/Rows/FoodButton
@onready var food_breakdown: VBoxContainer = $Control/Rows/FoodBreakdown
@onready var wood_label: Label = $Control/Rows/WoodLabel
@onready var stone_label: Label = $Control/Rows/StoneLabel
@onready var water_label: Label = $Control/Rows/WaterLabel
@onready var population_label: Label = $Control/Rows/PopulationLabel
@onready var happiness_label: Label = $Control/Rows/HappinessLabel
@onready var build_button: Button = $Control/Rows/BuildButton
@onready var menu_button: Button = $Control/Rows/MenuButton
@onready var save_indicator: Label = $SaveIndicator

const RATE_REFRESH_INTERVAL := 1.0

## Only wood/stone go through the single-resource tween/label path now -
## the food family has its own multi-resource aggregate handling below
## (_update_food_display), since one HUD row no longer maps to one
## GameState.resources entry for food.
var _resource_labels: Dictionary = {}
var _displayed := {"wood": 0.0, "stone": 0.0}
var _count_tweens := {}
var _save_indicator_tween: Tween
var _rate_timer: Timer
var _food_breakdown_labels: Dictionary = {}
var _food_expanded := false


func _ready() -> void:
	_resource_labels = {"wood": wood_label, "stone": stone_label}
	wood_label.resized.connect(func() -> void: wood_label.pivot_offset = wood_label.size / 2)
	stone_label.resized.connect(func() -> void: stone_label.pivot_offset = stone_label.size / 2)
	water_label.resized.connect(func() -> void: water_label.pivot_offset = water_label.size / 2)
	population_label.resized.connect(func() -> void: population_label.pivot_offset = population_label.size / 2)
	happiness_label.resized.connect(func() -> void: happiness_label.pivot_offset = happiness_label.size / 2)
	food_button.resized.connect(func() -> void: food_button.pivot_offset = food_button.size / 2)
	food_button.pressed.connect(_on_food_button_pressed)
	GameState.resources_changed.connect(_on_resources_changed)
	GameState.population_changed.connect(_on_population_changed)
	GameState.water_changed.connect(_on_water_changed)
	GameState.storage_capacity_changed.connect(_on_storage_capacity_changed)
	build_button.pressed.connect(func() -> void: build_pressed.emit())
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())

	for food_resource in FOOD_BREAKDOWN_ORDER:
		var label := Label.new()
		food_breakdown.add_child(label)
		_food_breakdown_labels[food_resource] = label

	for resource_name in _resource_labels:
		_set_display(resource_name, GameState.resources[resource_name])
	_update_food_display()
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
## beer...) that don't have their own top-level HUD row - showing everything
## flat would make this compact corner panel unreasonably tall, so anything
## in FOOD_BREAKDOWN_ORDER folds into the collapsible Food row instead (see
## _update_food_display) and everything else that isn't in _resource_labels
## (e.g. "hops", which isn't edible and isn't shown anywhere yet) is simply
## ignored. This handler is wired to every resource change though, not just
## displayed ones, so it has to ignore anything it doesn't have a home for
## rather than assume one exists.
func _on_resources_changed(resource_name: String, total: float) -> void:
	if resource_name in FOOD_BREAKDOWN_ORDER:
		_update_food_display(true)
		return
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


## Rebuilds the collapsed/expanded Food row: the aggregate total (sum of
## GameState.FOOD_RESOURCES) on the clickable header, and every indented
## sub-row's own amount/cap/rate underneath. Not smoothly tweened like
## wood/stone's count-up (7 sub-values changing independently would read as
## more animation than this compact a readout can support) - `punch` still
## gets the same on-change juice those rows have, just skipped for the
## purely time-based per-second rate refresh so the row doesn't visibly
## pulse every second even when nothing actually changed.
func _update_food_display(punch: bool = false) -> void:
	var total := GameState.get_total_food()
	var arrow := "v" if _food_expanded else ">"
	food_button.text = "%s Food: %d" % [arrow, total]

	for resource_name in FOOD_BREAKDOWN_ORDER:
		var label: Label = _food_breakdown_labels.get(resource_name)
		if not label:
			continue
		var amount: float = GameState.resources.get(resource_name, 0.0)
		var rate := GameState.get_income_per_minute(resource_name)
		label.text = "    %s: %d/%d (%s%.1f/min)" % [FOOD_BREAKDOWN_LABELS[resource_name], amount, GameState.storage_capacity, "+" if rate >= 0.0 else "", rate]

	if punch:
		_punch_control(food_button)


func _on_food_button_pressed() -> void:
	_food_expanded = not _food_expanded
	food_breakdown.visible = _food_expanded
	_update_food_display()


func _refresh_rates() -> void:
	for resource_name in _resource_labels:
		_update_label_text(resource_name)
	_update_food_display()


func _punch(resource_name: String) -> void:
	var label: Label = _resource_labels.get(resource_name)
	if label:
		_punch_control(label)


func _punch_control(control: Control) -> void:
	control.scale = PUNCH_SCALE
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)


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
	_update_food_display()


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
