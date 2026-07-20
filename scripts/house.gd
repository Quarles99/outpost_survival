extends Area2D
class_name House

## Fires on left-click, same pattern as OutpostHall.clicked - Base decides
## what a click means (here, always "try to upgrade"; there's no other
## citizen-selection interaction for a passive building like this one).
signal clicked

@export var display_name: String = "House"
@export var population_capacity: int = 2
## Same purpose/wiring as Workstation.description - shown in the panel
## House's click now opens (see Base._on_house_clicked). House doesn't
## extend Workstation, so it needs its own copy of this field.
@export var description: String = ""
## Paid once, on top of the building's own placement cost, to grant
## UPGRADE_CAPACITY_BONUS extra population capacity - see
## Base._on_house_clicked for the actual spend/grant flow (kept there, not
## here, since only Base/GameState know whether the player can afford it).
## Raw stone dropped entirely in favor of brick (explicit correction - an
## upgraded ("stone") house should be built from worked brick, not the raw
## ore itself) plus wood, so a Stone Mine -> Brickmaker chain becomes a real
## prerequisite for upgrading a House, per the stone-brick backlog item
## ("used for upgraded houses, brewery, mill, and other advanced buildings").
## Wood/brick raised 20.0/10.0 -> 100.0/50.0 via Outpost_Survival/Game
## Systems/Balance.md's edit-and-hand-back workflow.
const UPGRADE_COST := {"brick": 50.0, "wood": 100.0}
const UPGRADE_CAPACITY_BONUS := 2

## See Workstation.XRAY_MATERIAL's doc comment - same shared material, same
## reasoning. House doesn't extend Workstation, so it needs its own sprite
## reference/assignment rather than inheriting this for free.
const XRAY_MATERIAL := preload("res://shaders/xray_reveal_material.tres")

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D

## Whether this specific House has already spent its one-time upgrade -
## guards against paying twice for the same building. Restored from a save
## via mark_upgraded() rather than re-run through Base._on_house_clicked,
## since the capacity bonus itself is already covered by the save's raw
## GameState.population_capacity total (see Base._restore_placed_buildings'
## doc comment) - only the flag/label need to catch back up.
var upgraded := false


func _ready() -> void:
	input_event.connect(_on_input_event)
	_update_label()
	sprite.material = XRAY_MATERIAL


## No name line (dropped per an explicit request, see
## Workstation._update_label's own doc comment) - just the upgraded status,
## when there's any to show.
func _update_label() -> void:
	label.text = "Upgraded" if upgraded else ""


## Applies the upgrade's state/label change only - spending the cost and
## granting the capacity bonus are the caller's responsibility (see
## Base._on_house_clicked and _restore_placed_buildings' differing needs).
func mark_upgraded() -> void:
	upgraded = true
	_update_label()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		clicked.emit()
