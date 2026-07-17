extends Workstation
class_name LumberCamp

## How far (in grid tiles) an assigned worker will search for trees to chop
## or empty ground to replant on.
@export var search_radius: float = 4.5
## Total trees (mature or growing) this camp tries to keep standing within
## search_radius. Workers plant whenever the local count is under this,
## regardless of who chopped what - a shared sustainability target, not a
## per-worker replant quota. Deliberately set above Base's initial scatter
## (12 trees within radius 5.0 of the camp - see Base.INITIAL_TREE_COUNT) so
## a freshly-assigned worker starts topping the forest up right away rather
## than only once heavy chopping has thinned it out.
@export var optimal_tree_count: int = 16
## Halved 2.0 -> 1.0, then raised back 1.0 -> 2.0, via Outpost_Survival/
## Balance.md's edit-and-hand-back workflow.
@export var wood_per_chop: float = 2.0
## Doubled from 1.2 alongside Workstation.work_interval, per an explicit
## request to halve work pace across the board; nudged 2.4 -> 2.0 via
## Outpost_Survival/Balance.md's edit-and-hand-back workflow.
@export var chop_interval: float = 2.0


func get_skill_id() -> String:
	return "lumberjacking"
