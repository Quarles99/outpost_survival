extends Workstation
class_name ConstructionSite

## Overrides Workstation.max_workers' exported default of 1 - same pattern
## TrainingGround.get_unit_cap()/_ready() already uses to override it for
## itself. Lets several citizens haul labor into the same site at once
## instead of it sitting idle while every construction-trained citizen but
## one is stuck hauling - see Character._run_construction_loop's
## per-worker EFFECTIVENESS_EXPONENT for the "reduced effectiveness"
## tradeoff that keeps this from just linearly multiplying build speed.
## First-pass number, not tuned via playtesting.
const MAX_BUILDERS := 3


func _ready() -> void:
	max_workers = MAX_BUILDERS
	super._ready()
	## Each of the per-footprint-shape scenes (ConstructionSite1x1/2x2/2x4)
	## scatters several Sprite2D props (Replace the construction site sprite
	## with a composite sprite made with current sprite packs.md) instead of
	## the single $Sprite2D Workstation.refresh_visual() already applies
	## XRAY_MATERIAL to - same "walk every Sprite2D child" pattern
	## StorageFacility.gd uses for its own Pile1-4, so every prop (not just
	## the canonical one) correctly x-ray-reveals when a character walks
	## behind the site, same as every other occluder class.
	for child in get_children():
		if child is Sprite2D:
			child.material = XRAY_MATERIAL


## Workstation.refresh_visual() only modulates the single canonical
## $Sprite2D - same "walk every Sprite2D child" reasoning as the
## XRAY_MATERIAL pass in _ready() above, so every scattered prop shares the
## same sprite_tint/disabled dimming instead of just the one Workstation
## itself knows about.
func refresh_visual() -> void:
	super.refresh_visual()
	var tint: Color = sprite_tint * (DISABLED_TINT if disabled else Color.WHITE)
	for child in get_children():
		if child is Sprite2D:
			child.modulate = tint


## Emitted once every entry in materials_needed has been fully delivered -
## Base listens (Base._on_construction_materials_ready) to add this site to
## `posts` for the first time, making it eligible for automatic job
## assignment (see Base._run_job_assignment) exactly like any other job
## post. Deliberately kept OUT of `posts` before this fires - see
## materials_needed's own doc comment for why.
signal materials_ready

## Emitted once labor_completed reaches labor_required - Base listens
## (Base._on_construction_complete) to swap this site for the real building
## and free this node.
signal construction_complete

## Which BuildingCatalog option this site becomes once finished.
var target_option_id: String = ""

## resource_name -> remaining amount still needed, seeded from the target
## option's own cost dict and emptied out (keys erased, not left at 0.0) as
## haulers deliver each resource - see Character._deliver_construction_material.
## An empty dict means every material has arrived; materials_are_ready()
## reads that directly rather than a separate bool, so there's only one
## source of truth for "is this site fully stocked". Not delivered through
## the single-resource input_buffer/get_input_resource() path every other
## Workstation subclass uses - a construction site can need several
## different resources at once (e.g. a Storage Facility needs wood AND
## stone), which that path has no way to express.
var materials_needed: Dictionary = {}

## How much labor this site needs (see Base._labor_required_for) and how
## much a construction-skilled worker has put in so far - see
## Character._run_construction_loop, which is only ever running once this
## site is in `posts` (i.e. materials_are_ready() is already true).
var labor_required: float = 0.0
var labor_completed: float = 0.0


func get_skill_id() -> String:
	return "construction"


## Construction sites don't use the single-resource delivery path at all -
## see materials_needed above.
func get_input_resource() -> String:
	return ""


func materials_are_ready() -> bool:
	return materials_needed.is_empty()


func labor_progress() -> float:
	return 0.0 if labor_required <= 0.0 else clampf(labor_completed / labor_required, 0.0, 1.0)


## Called by Character._run_construction_loop once labor_completed reaches
## labor_required - kept as a method (rather than the work loop emitting
## the signal directly) so "this site is finished" has one obvious owner.
func mark_complete() -> void:
	construction_complete.emit()


## materials_needed/labor_completed are mutated directly by Character (the
## same "haul functions poke the post's fields directly" pattern
## output_buffer/input_buffer already use elsewhere), so nothing calls
## _update_label() automatically when they change - callers refresh the
## label explicitly through this after each delivery/labor tick.
func refresh_label() -> void:
	_update_label()


## "Needs: 4 Wood, 2 Stone\n0/1" during the materials phase, or
## "Building 42%\n1/1" once labor has started - overrides Workstation's own
## "<active>/<max>" so the in-world label actually communicates which of
## the two phases this site is in, rather than always reading like a
## finished, idle job post. No name line (dropped per an explicit request,
## see Workstation._update_label's own doc comment) - just the two status
## lines.
func _update_label() -> void:
	var lines: Array[String] = []
	if not materials_are_ready():
		var parts: Array[String] = []
		for resource_name in materials_needed:
			parts.append("%d %s" % [ceili(materials_needed[resource_name]), resource_name.capitalize()])
		lines.append("Needs: %s" % ", ".join(parts))
	else:
		var suffix := " (Disabled)" if disabled else ""
		lines.append("Building %d%%%s" % [roundi(labor_progress() * 100.0), suffix])
		lines.append("%d/%d" % [active_workers, max_workers])
	label.text = "\n".join(lines)
