extends CanvasLayer
class_name HUD

signal build_pressed
signal demolish_pressed
signal menu_pressed
signal attack_pressed
signal speed_pressed
signal citizens_pressed
## Fired by RallyButton - see Base._on_rally_pressed. Only enabled while an
## orc is selected (and at least one TrainingGround soldier exists) via
## set_rally_enabled, same enable-gating idea as AttackButton's own guard
## inside _on_attack_pressed, just surfaced on the button itself instead.
signal rally_pressed

const COUNT_DURATION := 0.35
const PUNCH_SCALE := Vector2(1.15, 1.15)

## Order the Food grid's individual resource icons are listed in - every
## GameState.FOOD_RESOURCES entry (edible, counted in the Food bar's
## aggregate total) followed by grain/flour (tracked per the design ask, but
## inedible on their own - see GameState.FOOD_RESOURCES's doc comment - so
## excluded from that aggregate).
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

@onready var food_breakdown: GridContainer = $Control/Margin/Rows/FoodBreakdown
@onready var wood_label: Label = $Control/Margin/Rows/WoodRow/WoodLabel
@onready var wood_icon: TextureRect = $Control/Margin/Rows/WoodRow/Icon
@onready var stone_label: Label = $Control/Margin/Rows/StoneRow/StoneLabel
@onready var stone_icon: TextureRect = $Control/Margin/Rows/StoneRow/Icon
@onready var brick_label: Label = $Control/Margin/Rows/BrickRow/BrickLabel
@onready var brick_icon: TextureRect = $Control/Margin/Rows/BrickRow/Icon
@onready var water_label: Label = $Control/Margin/Rows/WaterLabel
@onready var population_label: Label = $Control/Margin/Rows/PopulationLabel
@onready var idle_label: Label = $Control/Margin/Rows/IdleLabel
@onready var happiness_label: Label = $Control/Margin/Rows/HappinessLabel
@onready var day_label: Label = $Control/Margin/Rows/DayLabel
@onready var build_button: Button = $Control/Margin/Rows/BuildButton
@onready var demolish_button: Button = $Control/Margin/Rows/DemolishButton
@onready var citizens_button: Button = $Control/Margin/Rows/CitizensButton
@onready var attack_button: Button = $Control/Margin/Rows/AttackButton
@onready var rally_button: Button = $Control/Margin/Rows/RallyButton
@onready var speed_button: Button = $Control/Margin/Rows/SpeedButton
@onready var menu_button: Button = $Control/Margin/Rows/MenuButton
@onready var save_indicator: Label = $SaveIndicator
@onready var food_bar_frame: Control = $FoodBarPanel/FoodBarFrame
@onready var food_bar_fill: ColorRect = $FoodBarPanel/FoodBarFrame/Fill
@onready var food_bar_meal_warning: ColorRect = $FoodBarPanel/FoodBarFrame/MealWarning
@onready var food_bar_value: Label = $FoodBarPanel/FoodBarValue

const RATE_REFRESH_INTERVAL := 1.0

const FOOD_BAR_MEAL_WARNING_COLOR := Color(0.85, 0.25, 0.25, 0.85)

## Only wood/stone go through the single-resource tween/label path now -
## the food family has its own multi-resource aggregate handling below
## (_update_food_display), since one HUD row no longer maps to one
## GameState.resources entry for food.
var _resource_labels: Dictionary = {}
var _displayed := {"wood": 0.0, "stone": 0.0, "brick": 0.0}
var _count_tweens := {}
var _save_indicator_tween: Tween
var _rate_timer: Timer
var _food_breakdown_labels: Dictionary = {}
var _food_breakdown_icons: Dictionary = {}
## resource_name -> total active_workers currently producing it, pushed by
## Base.set_worker_counts (see that function's own doc comment for why this
## has to be a direct call rather than a GameState signal - it needs the
## character/post roster, which only Base owns). Read by _update_label_text/
## _update_food_display to append the "(workers)" suffix every resource row
## now shows (Make the resource display consistent across all resources.md).
var _worker_counts: Dictionary = {}
var _idle_count := 0


func _ready() -> void:
	_resource_labels = {"wood": wood_label, "stone": stone_label, "brick": brick_label}
	wood_icon.texture = ResourceIcons.get_icon("wood")
	stone_icon.texture = ResourceIcons.get_icon("stone")
	brick_icon.texture = ResourceIcons.get_icon("brick")
	_wire_tooltip(wood_icon, func() -> String: return "Wood", func() -> String: return _tooltip_body_for_resource("wood"))
	_wire_tooltip(stone_icon, func() -> String: return "Stone", func() -> String: return _tooltip_body_for_resource("stone"))
	_wire_tooltip(brick_icon, func() -> String: return "Brick", func() -> String: return _tooltip_body_for_resource("brick"))
	_wire_tooltip(water_label, func() -> String: return "Water", func() -> String: return "Available once any Well is built - also boosts nearby Farm output (see Well's own description).\nStatus: %s" % ("Available" if GameState.has_water() else "None"))
	_wire_tooltip(population_label, func() -> String: return "Population", func() -> String: return "Housed citizens vs. total capacity, from House and the Outpost Hall.")
	_wire_tooltip(idle_label, func() -> String: return "Idle Workers", func() -> String: return "Citizens with no job post assigned. They haul resources automatically until a post opens up for them.")
	_wire_tooltip(happiness_label, func() -> String: return "Happiness", func() -> String: return "Average citizen happiness. Higher happiness boosts production; low happiness hurts it.")
	_wire_tooltip(day_label, func() -> String: return "Day/Night", func() -> String: return "The settlement's day/night clock - affects work schedules and meal timing.")
	wood_label.resized.connect(func() -> void: wood_label.pivot_offset = wood_label.size / 2)
	stone_label.resized.connect(func() -> void: stone_label.pivot_offset = stone_label.size / 2)
	brick_label.resized.connect(func() -> void: brick_label.pivot_offset = brick_label.size / 2)
	water_label.resized.connect(func() -> void: water_label.pivot_offset = water_label.size / 2)
	population_label.resized.connect(func() -> void: population_label.pivot_offset = population_label.size / 2)
	idle_label.resized.connect(func() -> void: idle_label.pivot_offset = idle_label.size / 2)
	happiness_label.resized.connect(func() -> void: happiness_label.pivot_offset = happiness_label.size / 2)
	## food_bar_frame's actual size isn't reliable until the VBoxContainer it
	## sits in has completed a layout pass (it stretches the frame to the
	## container's own width, wider than the frame's own custom_minimum_size)
	## - a call made synchronously in _ready(), before that pass has
	## necessarily happened, can compute against a stale/too-narrow size.
	## Listening for resized (also fires on a window resize, unlike a single
	## _ready()-time call) keeps the fill/overlay correctly sized regardless
	## of exactly when layout resolves.
	food_bar_frame.resized.connect(_update_food_bar)
	GameState.resources_changed.connect(_on_resources_changed)
	GameState.population_changed.connect(_on_population_changed)
	GameState.water_changed.connect(_on_water_changed)
	GameState.storage_capacity_changed.connect(_on_storage_capacity_changed)
	build_button.pressed.connect(func() -> void: build_pressed.emit())
	demolish_button.pressed.connect(func() -> void: demolish_pressed.emit())
	citizens_button.pressed.connect(func() -> void: citizens_pressed.emit())
	attack_button.pressed.connect(func() -> void: attack_pressed.emit())
	rally_button.pressed.connect(func() -> void: rally_pressed.emit())
	rally_button.disabled = true
	speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())

	for food_resource in FOOD_BREAKDOWN_ORDER:
		var cell := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = ResourceIcons.get_icon(food_resource)
		cell.add_child(icon)
		var label := Label.new()
		cell.add_child(label)
		food_breakdown.add_child(cell)
		_food_breakdown_icons[food_resource] = icon
		_food_breakdown_labels[food_resource] = label
		_wire_tooltip(icon, func() -> String: return FOOD_BREAKDOWN_LABELS[food_resource], func() -> String: return _tooltip_body_for_resource(food_resource))

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


## Base recomputes this every time orc selection (or the soldier roster)
## could have changed - see Base._on_orc_selected/_deselect_orc.
func set_rally_enabled(value: bool) -> void:
	rally_button.disabled = not value


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
## beer...) that don't have their own top-level HUD row - anything in
## FOOD_BREAKDOWN_ORDER goes to the Food grid instead (see
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


## "50 (2)" - amount, then the count of citizens currently working a post
## that produces this resource (_worker_counts, pushed by Base.
## set_worker_counts) in parens. Capacity/rate used to be inline here too -
## moved to the tooltip instead (see _tooltip_body_for_resource) once the
## mouseover tooltip system existed to hold it, per Make the resource
## display consistent across all resources.md's "Icon: Amount (workers)"
## format applying to every resource the same way, not just wood/stone.
func _update_label_text(resource_name: String) -> void:
	var label: Label = _resource_labels.get(resource_name)
	if not label:
		return
	var value: float = _displayed[resource_name]
	label.text = "%d (%d)" % [value, _worker_counts.get(resource_name, 0)]


## Rebuilds the Food grid: every individual food resource always shows its
## own icon + "amount (workers)" (no collapsed/expanded state anymore -
## removed per an explicit request that each food type stay individually
## visible rather than folded under a dropdown), the same format
## _update_label_text now gives wood/stone - capacity/rate live in the
## tooltip only (see that function's own doc comment) since a full
## "%d/%d (+%.1f/min)" readout per row doesn't fit a multi-column grid at a
## legible width. Not smoothly tweened like wood/stone's count-up (7
## sub-values changing independently would read as more animation than
## this compact a readout can support) - `punch` still gets the same
## on-change juice, just applied to the whole grid at once, and skipped
## for the purely time-based per-second rate refresh so it doesn't visibly
## pulse every second even when nothing actually changed.
func _update_food_display(punch: bool = false) -> void:
	for resource_name in FOOD_BREAKDOWN_ORDER:
		var label: Label = _food_breakdown_labels.get(resource_name)
		var icon: TextureRect = _food_breakdown_icons.get(resource_name)
		if not label or not icon:
			continue
		var amount: float = GameState.resources.get(resource_name, 0.0)
		label.text = "%d (%d)" % [amount, _worker_counts.get(resource_name, 0)]

	if punch:
		_punch_control(food_breakdown)


## Vertical Food bar in the bottom-right corner (per Ideas/Completed/Resource
## Consumption UI.md) - a graphical companion to the individual food-type
## icons above (Control/Rows/FoodBreakdown), not a replacement, so a player
## can gauge aggregate stock and trend at a glance without reading every
## icon. food_bar_fill grows from the bottom of food_bar_frame same as any
## "tank" gauge.
##
## Just the one overlay band now - a green rate-extrapolated growth preview
## used to sit above the fill too, but production actually arrives in
## discrete haul trips at each workstation's own work_interval, a totally
## separate cadence from the day/night meal timing this bar's other overlay
## (food_bar_meal_warning) is keyed to - a smoothly-extrapolated "next 30s"
## band didn't correspond to anything real happening on that schedule, so it
## was removed rather than kept as a misleading projection. Per an explicit
## request, not a GameState change - GameState.get_food_income_per_minute()
## still exists and still drives the text Food row's rate readout, just no
## longer this bar's own overlay.
## - food_bar_meal_warning (red, inside the top of the fill): the *exact*,
##   always-known cost of the next meal (FOOD_PER_CITIZEN_PER_MEAL *
##   population_count), clamped to the fill's own height so it can't show
##   losing more than currently in stock. Shown any time there's a
##   population to feed, since a meal is coming regardless of current rate -
##   this is "how big a bite is coming," not "are you currently trending down."
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

	food_bar_value.text = "%d/%d" % [total, capacity]


func _refresh_rates() -> void:
	for resource_name in _resource_labels:
		_update_label_text(resource_name)
	_update_food_display()
	_update_food_bar()


## Connects a Control to TooltipManager (Actionable Ideas/Mouseover tooltip
## system.md) - `title`/`body` are Callables rather than plain Strings so
## the tooltip always reflects live game state (current water/population/
## resource totals) at the moment the hover delay actually elapses, not
## whatever those values happened to be back when _ready() first wired the
## connection.
func _wire_tooltip(control: Control, title: Callable, body: Callable) -> void:
	control.mouse_entered.connect(func() -> void: TooltipManager.request(title.call(), body.call()))
	control.mouse_exited.connect(func() -> void: TooltipManager.cancel())


## Shared by every resource icon (wood/stone/brick rows and the Food grid's
## per-crop icons) - description (ResourceIcons.get_description) plus "Max
## capacity" per Mouseover tooltip system.md's companion note (this file).
## Rate (the old inline "+2.0/min") was tried here too but dropped
## entirely per an explicit request - just description + capacity now.
func _tooltip_body_for_resource(resource_name: String) -> String:
	var lines: Array[String] = []
	var description := ResourceIcons.get_description(resource_name)
	if not description.is_empty():
		lines.append(description)
	lines.append("Max capacity: %d" % GameState.storage_capacity)
	return "\n".join(lines)


## Pushed directly by Base at the end of _run_job_assignment() (see
## Base._update_resource_worker_counts's own doc comment for why this has
## to be a direct call, not a GameState signal) - refreshes every resource
## row's "(workers)" suffix and the Idle Workers stat in one pass.
func set_worker_counts(per_resource: Dictionary, idle_count: int) -> void:
	_worker_counts = per_resource
	for resource_name in _resource_labels:
		_update_label_text(resource_name)
	_update_food_display()
	var changed := idle_count != _idle_count
	_idle_count = idle_count
	idle_label.text = "Idle: %d" % idle_count
	if changed:
		_punch_control(idle_label)


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
