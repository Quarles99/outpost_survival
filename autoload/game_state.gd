extends Node

signal resources_changed(resource_name: String, total: float)
signal population_changed(count: int, capacity: int)
signal water_changed(available: bool)
signal storage_capacity_changed(capacity: float)

## Food each citizen eats per second, drained continuously regardless of
## whether they're assigned to a post.
const FOOD_PER_CITIZEN := 0.3
const CONSUMPTION_INTERVAL := 1.0

## Every resource that satisfies hunger - a citizen doesn't care which kind
## it's eating, so consumption draws from these in order until the need is
## met or all of them run dry. Order matters: "food" (the original Farm's
## direct output) is drained first, refined/slower-to-produce crops last, so
## the harder-won foods are held in reserve rather than spent first. Grain,
## flour, hops, and beer are deliberately excluded - they're intermediate or
## luxury goods (see farm.gd's Alternative Crop Types docs), not something a
## citizen can eat directly. Exposed as a const so the (future) Happiness
## system can measure "food variety" by how many of these currently have
## stock, per the design doc's "food variety gives improved happiness".
const FOOD_RESOURCES := ["food", "bread", "potato", "fruit"]

var resources := {
	"food": 10.0,
	"wood": 10.0,
	"stone": 0.0,
	"grain": 0.0,
	"flour": 0.0,
	"bread": 0.0,
	"hops": 0.0,
	"beer": 0.0,
	"fruit": 0.0,
	"potato": 0.0,
}

var population_count := 3
var population_capacity := 3

## Ceiling each individual resource in `resources` is clamped to - not a
## shared pool split across resource types, a full cap that applies to each
## one independently (so e.g. food filling up doesn't crowd out wood).
## Baseline exists even with zero Storage Facilities built, both so the
## game isn't unplayable from turn one and so it's comfortably above the
## starting resources dict - Storage Facilities add on top of it.
const BASE_STORAGE_CAPACITY := 30.0
var storage_capacity := BASE_STORAGE_CAPACITY

## Water is deliberately not in `resources` - a Well provides unlimited
## access rather than a depletable stockpile, so this just counts how many
## exist (0 = no water access) rather than tracking an amount.
var water_wells := 0

## Settlement-wide production multiplier from the current happiness band -
## Base recomputes this every happiness tick (see its HAPPINESS_BANDS) and
## Character's work loops read it directly alongside each worker's own
## skill multiplier. Lives here rather than on Base since production code
## in character.gd already reaches into GameState for everything else it
## needs, and this needs to be readable without a Base reference.
var happiness_output_multiplier := 1.0

var _consumption_timer: Timer

## Rolling history of resource-pool snapshots, used to compute an income/min
## readout for the HUD. Sampled on its own timer rather than piggybacking on
## every add_resource() call, since production arrives in bursty haul-trip
## chunks (see character.gd) - what matters for a "rate" reading is the net
## change over a real time window, not the size of any single deposit.
const INCOME_SAMPLE_INTERVAL := 1.0
const INCOME_WINDOW_SECONDS := 60.0
var _income_history: Array[Dictionary] = []
var _income_sample_timer: Timer


func _ready() -> void:
	_consumption_timer = Timer.new()
	_consumption_timer.wait_time = CONSUMPTION_INTERVAL
	_consumption_timer.timeout.connect(_on_consumption_timeout)
	add_child(_consumption_timer)
	_consumption_timer.start()

	_income_sample_timer = Timer.new()
	_income_sample_timer.wait_time = INCOME_SAMPLE_INTERVAL
	_income_sample_timer.timeout.connect(_sample_income_history)
	add_child(_income_sample_timer)
	_income_sample_timer.start()
	_sample_income_history()


func _on_consumption_timeout() -> void:
	_consume_food(FOOD_PER_CITIZEN * population_count * CONSUMPTION_INTERVAL)


## Drains up to `amount` total hunger need from FOOD_RESOURCES in priority
## order. Unlike add_resource(-x) on a single resource, this can't be
## satisfied by one type alone running negative - it just stops once every
## food-equivalent resource is empty, same as add_resource's existing
## floor-at-0 behavior but spread across several stockpiles instead of one.
func _consume_food(amount: float) -> void:
	var remaining := amount
	for resource_name in FOOD_RESOURCES:
		if remaining <= 0.0:
			return
		var take := minf(resources.get(resource_name, 0.0), remaining)
		if take > 0.0:
			add_resource(resource_name, -take)
			remaining -= take


func add_resource(resource_name: String, amount: float) -> void:
	resources[resource_name] = clampf(resources.get(resource_name, 0.0) + amount, 0.0, storage_capacity)
	resources_changed.emit(resource_name, resources[resource_name])


func can_afford(cost: Dictionary) -> bool:
	for resource_name in cost:
		if resources.get(resource_name, 0.0) < cost[resource_name]:
			return false
	return true


func spend(cost: Dictionary) -> void:
	for resource_name in cost:
		add_resource(resource_name, -cost[resource_name])


func add_population_capacity(amount: int) -> void:
	population_capacity += amount
	population_changed.emit(population_count, population_capacity)


func add_water_well(amount: int = 1) -> void:
	water_wells += amount
	water_changed.emit(has_water())


func has_water() -> bool:
	return water_wells > 0


func add_storage_capacity(amount: float) -> void:
	storage_capacity += amount
	storage_capacity_changed.emit(storage_capacity)


func _sample_income_history() -> void:
	_income_history.append({"time": Time.get_ticks_msec() / 1000.0, "resources": resources.duplicate()})
	while _income_history.size() > 1 and Time.get_ticks_msec() / 1000.0 - _income_history[0]["time"] > INCOME_WINDOW_SECONDS:
		_income_history.pop_front()


## Net change in `resource_name` per minute, measured over however much of
## the trailing INCOME_WINDOW_SECONDS window has elapsed so far (shorter
## just after boot). This is net income into the stockpile, not gross
## production - a workstation whose output is being lost to a full storage
## cap (see storage_capacity docs above) won't show up here, since nothing
## actually reached the resource pool.
func get_income_per_minute(resource_name: String) -> float:
	if _income_history.is_empty():
		return 0.0
	var oldest: Dictionary = _income_history[0]
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - oldest["time"]
	if elapsed <= 0.0:
		return 0.0
	var delta: float = resources.get(resource_name, 0.0) - (oldest["resources"] as Dictionary).get(resource_name, 0.0)
	return delta / elapsed * 60.0
