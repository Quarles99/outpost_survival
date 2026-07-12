extends Node

signal resources_changed(resource_name: String, total: float)
signal population_changed(count: int, capacity: int)
signal water_changed(available: bool)
signal storage_capacity_changed(capacity: float)

## Food each citizen eats per second, drained continuously regardless of
## whether they're assigned to a post. Lowered from the original 0.3 - early
## playtesting showed the entire economy had to be devoted to farming just
## to keep the population fed, leaving little room to build anything else.
const FOOD_PER_CITIZEN := 0.2
const CONSUMPTION_INTERVAL := 1.0

## Every resource that satisfies hunger - a citizen doesn't care which kind
## it's eating. Consumption (see _consume_food) splits the need *evenly*
## across whichever of these currently have stock, rather than draining
## them one at a time in list order - a town with cabbage, bread, and beer
## all in stock eats a third of its hunger need from each every tick, not
## bread only once cabbage is fully gone. This list's order therefore has
## no priority meaning anymore; it's just a stable iteration/display order.
## Grain and flour are deliberately excluded - they're intermediate goods,
## not something a citizen can eat directly (see farm.gd's Alternative Crop
## Types docs) - still tracked/displayed (see HUD.FOOD_BREAKDOWN_ORDER) just
## not consumed by hunger. Exposed as a const so the Happiness system can
## measure "food variety" by how many of these currently have stock, per
## the design doc's "food variety gives improved happiness", and so the HUD
## can sum them for its aggregate "Food" readout (see get_total_food()).
const FOOD_RESOURCES := ["cabbage", "potato", "fruit", "bread", "beer"]

## Kept as a const (rather than inlining the dict literal into `resources`
## below) so reset_to_defaults() can restore exactly this without a second,
## driftable copy of the same starting values.
const DEFAULT_RESOURCES := {
	"cabbage": 10.0,
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
var resources := DEFAULT_RESOURCES.duplicate()

const DEFAULT_POPULATION := 3
var population_count := DEFAULT_POPULATION
var population_capacity := DEFAULT_POPULATION

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


## Drains up to `amount` total hunger need, split evenly across whichever
## FOOD_RESOURCES currently have stock rather than one type at a time - a
## town with 3 food types stocked eats a third of its need from each. When a
## type runs dry partway through a round (its even share exceeds what it has
## left), the shortfall is redistributed evenly across the remaining
## stocked types on the next round, so the full `amount` still gets consumed
## as long as *some* food-equivalent resource has enough between them (same
## floor-at-0 behavior as add_resource, just spread across several
## stockpiles and rounds instead of one deduction).
func _consume_food(amount: float) -> void:
	var remaining := amount
	var candidates := FOOD_RESOURCES.filter(func(r: String) -> bool: return resources.get(r, 0.0) > 0.0)
	while remaining > 0.0 and not candidates.is_empty():
		var share := remaining / candidates.size()
		var next_candidates: Array = []
		var consumed_this_round := 0.0
		for resource_name in candidates:
			var take := minf(resources.get(resource_name, 0.0), share)
			if take > 0.0:
				add_resource(resource_name, -take)
				consumed_this_round += take
			if resources.get(resource_name, 0.0) > 0.0:
				next_candidates.append(resource_name)
		remaining -= consumed_this_round
		if consumed_this_round <= 0.0:
			break
		candidates = next_candidates


func add_resource(resource_name: String, amount: float) -> void:
	resources[resource_name] = clampf(resources.get(resource_name, 0.0) + amount, 0.0, storage_capacity)
	resources_changed.emit(resource_name, resources[resource_name])


## Sum of every FOOD_RESOURCES stockpile - the number the HUD's collapsed
## "Food" row shows, and what Base's happiness tick uses for "does this
## settlement have any food at all" (a single named resource, "food", no
## longer exists as such - Alternative Crop Types split it into several).
func get_total_food() -> float:
	var total := 0.0
	for resource_name in FOOD_RESOURCES:
		total += resources.get(resource_name, 0.0)
	return total


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


## Restores every mutable field to its starting value and re-emits the
## signals that depend on them - for starting a brand new game without
## restarting the process. Unlike Base (freed and recreated whole every
## time MainMenu switches into Base.tscn), this autoload is created once
## and never destroyed, so nothing resets it on its own; Base._ready()
## calls this whenever it's about to start fresh rather than load a save.
func reset_to_defaults() -> void:
	resources = DEFAULT_RESOURCES.duplicate()
	population_count = DEFAULT_POPULATION
	population_capacity = DEFAULT_POPULATION
	storage_capacity = BASE_STORAGE_CAPACITY
	water_wells = 0
	happiness_output_multiplier = 1.0
	_income_history.clear()

	for resource_name in resources:
		resources_changed.emit(resource_name, resources[resource_name])
	population_changed.emit(population_count, population_capacity)
	water_changed.emit(has_water())
	storage_capacity_changed.emit(storage_capacity)


func _sample_income_history() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_income_history.append({"time": now, "resources": resources.duplicate()})
	## Keep at least one sample at-or-before "now - INCOME_WINDOW_SECONDS"
	## at all times (once that much history exists at all), rather than
	## discarding the current-oldest as soon as *it* crosses the window
	## boundary - only pop it once the *next* sample has also crossed, so
	## get_income_per_minute always has a valid "before" anchor to
	## interpolate from. Trimming as soon as the oldest exceeds the window
	## (the previous policy) meant the retained oldest sample's true age
	## could be anywhere up to a full INCOME_SAMPLE_INTERVAL past the
	## window - close enough to look right most of the time, but a
	## systematic over-count for a bursty producer (a hauler's output
	## arrives in discrete trip-sized chunks, not a smooth trickle), since
	## the window would silently run up to ~1.67% long on average.
	while _income_history.size() > 1 and _income_history[1]["time"] <= now - INCOME_WINDOW_SECONDS:
		_income_history.pop_front()


## Net change in `resource_name` per minute, measured over exactly the
## trailing INCOME_WINDOW_SECONDS (shorter just after boot, while there
## isn't that much history yet) - interpolated between whichever two
## samples straddle "now - INCOME_WINDOW_SECONDS" so the window length is
## always precise regardless of how coarse INCOME_SAMPLE_INTERVAL is (see
## _sample_income_history's doc comment for why an imprecise window
## matters here, not just adds noise). This is net income into the
## stockpile, not gross production - a workstation whose output is being
## lost to a full storage cap (see storage_capacity docs above) won't show
## up here, since nothing actually reached the resource pool.
func get_income_per_minute(resource_name: String) -> float:
	if _income_history.is_empty():
		return 0.0
	var now := Time.get_ticks_msec() / 1000.0
	var target_time := now - INCOME_WINDOW_SECONDS
	var oldest: Dictionary = _income_history[0]

	if target_time <= oldest["time"]:
		## Not enough history yet (still within INCOME_WINDOW_SECONDS of
		## boot) - use the oldest sample actually on hand and the real
		## elapsed time since it, same spirit as the full case below but
		## over a shorter, honest window rather than pretending it's 60s.
		var elapsed: float = now - oldest["time"]
		if elapsed <= 0.0:
			return 0.0
		var delta: float = resources.get(resource_name, 0.0) - (oldest["resources"] as Dictionary).get(resource_name, 0.0)
		return delta / elapsed * 60.0

	var before: Dictionary = oldest
	var after: Dictionary = oldest
	for entry in _income_history:
		if entry["time"] <= target_time:
			before = entry
		else:
			after = entry
			break

	var value_at_target: float
	if after["time"] <= before["time"]:
		value_at_target = (before["resources"] as Dictionary).get(resource_name, 0.0)
	else:
		var t: float = (target_time - before["time"]) / (after["time"] - before["time"])
		var before_val: float = (before["resources"] as Dictionary).get(resource_name, 0.0)
		var after_val: float = (after["resources"] as Dictionary).get(resource_name, 0.0)
		value_at_target = lerp(before_val, after_val, t)

	var delta: float = resources.get(resource_name, 0.0) - value_at_target
	return delta / INCOME_WINDOW_SECONDS * 60.0
