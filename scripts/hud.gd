extends CanvasLayer
class_name HUD

signal build_pressed
signal menu_pressed
signal attack_pressed
signal speed_pressed

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
@onready var day_label: Label = $Control/Rows/DayLabel
@onready var build_button: Button = $Control/Rows/BuildButton
@onready var attack_button: Button = $Control/Rows/AttackButton
@onready var speed_button: Button = $Control/Rows/SpeedButton
@onready var menu_button: Button = $Control/Rows/MenuButton
@onready var save_indicator: Label = $SaveIndicator
@onready var food_bar_frame: Control = $FoodBarPanel/FoodBarFrame
@onready var food_bar_fill: ColorRect = $FoodBarPanel/FoodBarFrame/Fill
@onready var food_bar_meal_warning: ColorRect = $FoodBarPanel/FoodBarFrame/MealWarning
@onready var food_bar_overlay: ColorRect = $FoodBarPanel/FoodBarFrame/Overlay
@onready var food_bar_value: Label = $FoodBarPanel/FoodBarValue

const RATE_REFRESH_INTERVAL := 1.0

## How far ahead the Food bar's green growth overlay projects, extrapolated
## from the current GameState.get_food_income_per_minute() rate - short
## enough to read as "about to happen" rather than a full-minute projection
## that would overshoot the bar entirely for anything gaining food quickly.
## Only used for the growth side now - see food_bar_meal_warning's doc
## comment on _update_food_bar for why the loss side no longer uses a rate
## extrapolation at all.
const FOOD_BAR_PREVIEW_SECONDS := 30.0
const FOOD_BAR_GAIN_COLOR := Color(0.4, 0.75, 0.35, 0.85)
const FOOD_BAR_MEAL_WARNING_COLOR := Color(0.85, 0.25, 0.25, 0.85)

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
	## food_bar_frame's actual size isn't reliable until the VBoxContainer it
	## sits in has completed a layout pass (it stretches the frame to the
	## container's own width, wider than the frame's own custom_minimum_size)
	## - a call made synchronously in _ready(), before that pass has
	## necessarily happened, can compute against a stale/too-narrow size.
	## Listening for resized (also fires on a window resize, unlike a single
	## _ready()-time call) keeps the fill/overlay correctly sized regardless
	## of exactly when layout resolves.
	food_bar_frame.resized.connect(_update_food_bar)
	food_button.pressed.connect(_on_food_button_pressed)
	GameState.resources_changed.connect(_on_resources_changed)
	GameState.population_changed.connect(_on_population_changed)
	GameState.water_changed.connect(_on_water_changed)
	GameState.storage_capacity_changed.connect(_on_storage_capacity_changed)
	build_button.pressed.connect(func() -> void: build_pressed.emit())
	attack_button.pressed.connect(func() -> void: attack_pressed.emit())
	speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())

	for food_resource in FOOD_BREAKDOWN_ORDER:
		var label := Label.new()
		food_breakdown.add_child(label)
		_food_breakdown_labels[food_resource] = label

	for resource_name in _resource_labels:
		_set_display(resource_name, GameState.resources[resource_name])
	_update_food_display()
	_update_food_bar()
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
		_update_food_bar()
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


## Vertical Food bar in the bottom-right corner (per Ideas/Completed/Resource
## Consumption UI.md) - a graphical companion to the existing text Food row
## above (Control/Rows/FoodButton), not a replacement, so a player can gauge
## stock and trend at a glance without opening the breakdown. food_bar_fill
## grows from the bottom of food_bar_frame same as any "tank" gauge.
##
## Two independent overlay bands, not one that switches between them (the
## original single-overlay version did, before GameState moved consumption
## off a continuous per-second drain onto two flat meals a day/night cycle -
## see FOOD_PER_CITIZEN_PER_MEAL): a smoothly-extrapolated rate no longer
## means anything sensible for the *loss* side specifically, since
## get_food_income_per_minute()'s rolling 60s window is mostly just
## production between meals, then briefly reads a huge false spike right
## after one (the meal itself scrolling through the window) before settling
## back - extrapolating that spike 30s forward would predict a further drop
## that isn't actually coming.
## - food_bar_meal_warning (red, inside the top of the fill): not a
##   projection at all - the *exact*, always-known cost of the next meal
##   (FOOD_PER_CITIZEN_PER_MEAL * population_count), clamped to the fill's
##   own height so it can't show losing more than currently in stock. Shown
##   any time there's a population to feed, since a meal is coming
##   regardless of current rate - this is "how big a bite is coming," not
##   "are you currently trending down."
## - food_bar_overlay (green, just above the fill): still the old rate-based
##   growth preview over FOOD_BAR_PREVIEW_SECONDS - production genuinely is
##   still continuous, so this half of the original design is still valid.
##   Only shown when the rate is positive; hidden otherwise rather than
##   trying to also express a negative rate here (that's what the meal
##   warning band is for now).
func _update_food_bar() -> void:
	var capacity := GameState.storage_capacity
	var total := GameState.get_total_food()
	var frame_size := food_bar_frame.size
	var fill_frac := clampf(total / capacity, 0.0, 1.0) if capacity > 0.0 else 0.0
	var fill_height := frame_size.y * fill_frac
	food_bar_fill.position = Vector2(0.0, frame_size.y - fill_height)
	food_bar_fill.size = Vector2(frame_size.x, fill_height)

	var meal_cost := GameState.FOOD_PER_CITIZEN_PER_MEAL * GameState.population_count
	if meal_cost > 0.0 and capacity > 0.0:
		var warning_frac := clampf(meal_cost / capacity, 0.0, fill_frac)
		var warning_height := warning_frac * frame_size.y
		food_bar_meal_warning.visible = true
		food_bar_meal_warning.color = FOOD_BAR_MEAL_WARNING_COLOR
		food_bar_meal_warning.position = Vector2(0.0, frame_size.y - fill_height)
		food_bar_meal_warning.size = Vector2(frame_size.x, warning_height)
	else:
		food_bar_meal_warning.visible = false

	var rate := GameState.get_food_income_per_minute()
	if rate <= 0.0:
		food_bar_overlay.visible = false
	else:
		var projected_total := clampf(total + rate * (FOOD_BAR_PREVIEW_SECONDS / 60.0), 0.0, capacity)
		var projected_frac := clampf(projected_total / capacity, 0.0, 1.0) if capacity > 0.0 else 0.0
		var band_height := (projected_frac - fill_frac) * frame_size.y
		food_bar_overlay.visible = band_height > 0.0
		food_bar_overlay.color = FOOD_BAR_GAIN_COLOR
		food_bar_overlay.position = Vector2(0.0, frame_size.y - fill_height - band_height)
		food_bar_overlay.size = Vector2(frame_size.x, band_height)

	food_bar_value.text = "%d/%d" % [total, capacity]


func _on_food_button_pressed() -> void:
	_food_expanded = not _food_expanded
	food_breakdown.visible = _food_expanded
	_update_food_display()


func _refresh_rates() -> void:
	for resource_name in _resource_labels:
		_update_label_text(resource_name)
	_update_food_display()
	_update_food_bar()


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
	_update_food_bar()


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


## Called directly by Base on DayNightCycle.day_started/night_started (and
## once at boot/load to snap to whatever phase was restored) - same direct-
## call shape as set_happiness above, since Base is what actually listens to
## the autoload's signals.
func set_day_label(day: int, is_day: bool) -> void:
	day_label.text = "Day %d - %s" % [day, "Day" if is_day else "Night"]
	day_label.scale = PUNCH_SCALE
	var tween := create_tween()
	tween.tween_property(day_label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)


## Called directly by Base whenever the fast-forward multiplier changes
## (button click or +/- keys - see Base._apply_speed) - same direct-call
## shape as set_happiness/set_day_label above.
func set_speed_label(multiplier: float) -> void:
	speed_button.text = "Speed: %sx" % (str(int(multiplier)) if multiplier == floor(multiplier) else str(multiplier))
