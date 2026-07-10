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

var _consumption_timer: Timer


func _ready() -> void:
	_consumption_timer = Timer.new()
	_consumption_timer.wait_time = CONSUMPTION_INTERVAL
	_consumption_timer.timeout.connect(_on_consumption_timeout)
	add_child(_consumption_timer)
	_consumption_timer.start()


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
