extends Area2D
class_name Character

## Fired on left-click - Base selects this citizen and opens their skill
## panel (view-only; job assignment is fully automatic, see
## Base._run_job_assignment).
signal clicked(character: Character)

const BOB_AMPLITUDE := 2.5
const BOB_SPEED := 1.4
## Deliberately slow ("realistic travel time" over instant snapping) - a
## work post sitting a few tiles from the stockpile should read as a real
## walk, not a blip. Halved (140.0 -> 70.0), with MIN/MAX_MOVE_DURATION
## doubled to match, per an explicit request to slow the whole town economy
## down by a factor of 2 - see Base's fast-forward system (Engine.time_scale)
## for the companion feature letting a player compress that back down when
## they don't need to watch every trip in real time.
const MOVE_SPEED := 70.0
const MIN_MOVE_DURATION := 0.6
## Lowered 8.0 -> 2.0, then raised 2.0 -> 20.0, via Outpost_Survival/
## Balance.md's edit-and-hand-back workflow - a very long haul can now take
## noticeably longer than a short one (opposite of the brief 2.0s pass).
const MAX_MOVE_DURATION := 20.0
const IDLE_RETRY_DELAY := 2.5
## Flat xp granted per action, regardless of output - still used for
## strength (per haul trip, see _haul_to_stockpile/_deliver_to_post/
## _deliver_construction_material), construction labor, and training drill,
## none of which represent a real GameState resource amount to scale
## against. No longer used by the three actual resource-production loops
## (_run_generic_work_loop, _run_farm_loop, _run_lumberjack_loop) - see
## XP_PER_RESOURCE_UNIT below for those, per an explicit request that xp
## gained should scale with resources collected instead of being flat.
const XP_PER_GATHER := 4.0
## Xp per unit of resource actually produced this tick, for the three real-
## resource-production loops only (see XP_PER_GATHER's doc comment for which
## ones still use the flat rate instead). Calibrated so a level-1 worker at
## a 1.0-output_per_tick post (e.g. Cabbage Farm) still grants exactly
## XP_PER_GATHER's old 4.0 xp/tick - level 1 unchanged, only levels above it
## diverge, since `amount` grows with the worker's own skill multiplier
## (data.get_skill_multiplier) from here on. That growth is deliberately
## *not* left to snowball unchecked, unlike the flat-rate era's explicit
## "would make high levels snowball even faster" concern above: see
## SkillCurve._ensure_table's multiplier_for_level scaling, added alongside
## this, which grows the xp *required* per level by that exact same factor -
## per an explicit request that xp needed should scale at the same rate xp
## gained does, so the number of actions needed to clear a level stays what
## the base RuneScape-style curve alone would have given, even though both
## the granted and required numbers are now bigger at high level than the
## unscaled curve would show.
const XP_PER_RESOURCE_UNIT := 4.0
## Brief hold at the stockpile while dropping off/picking up, so even a
## short haul doesn't read as an instant teleport-and-return.
const STOCKPILE_PAUSE := 0.3
## Farm-family output bonus once at least one Well is built (GameState.
## has_water()) - more food/crops for the *same* input cost, not a discount
## on the input itself, so this only scales farm.output_per_tick, never
## input_needed. Binary (built or not) rather than eased like the
## happiness multiplier - water access itself doesn't gradually change.
const WATER_FARM_OUTPUT_BONUS := 1.25
## Idle haulers ignore a workstation buffer below this - not worth a whole
## round trip for a trickle.
const HAUL_MIN_THRESHOLD := 1.0
## Labor progress a construction worker adds to a ConstructionSite per
## work_interval tick, before their own construction skill/the settlement's
## happiness multiplier - see _run_construction_loop. A first-pass number,
## not tuned via playtesting (see Base._labor_required_for for how a site's
## total labor_required is derived from it). Tried raising to 1.2 (flat 20%
## build-speed request), then lowering to 0.26 (a uniform slowdown so the
## whole Lumber Camp -> Farm -> House progression would track Day 1's
## clock) - both rolled back. The actual chosen fix for "first House about
## halfway through Day 1" was on the resource side instead, not this
## constant: see GameState.DEFAULT_RESOURCES's wood comment - starting wood
## only covers the Lumber Camp now, so both the Farm and the House have to
## be earned via real wood gathering (naturally paced by production, not
## an artificial labor-speed knob) before either can be built. Raised
## 1.0 -> 2.0 via Outpost_Survival/Game Systems/Balance.md's edit-and-
## hand-back workflow.
const CONSTRUCTION_LABOR_PER_TICK := 2.0
## "Reduced effectiveness" for a construction site worked by several
## builders at once (see ConstructionSite.MAX_BUILDERS) - each builder's own
## per-tick gain is scaled by 1/sqrt(site.active_workers) rather than left
## at 1.0 flat, so total site throughput still improves with more workers
## but with diminishing returns (2 workers ~1.41x a single worker's speed,
## 3 workers ~1.73x, not a flat 2x/3x) rather than either no benefit at all
## or several workers trivially multiplying speed with zero tradeoff for
## crowding onto one site. Read at the moment each tick resolves (not
## captured once per worker session), so it responds immediately as
## workers join/leave mid-build rather than staying stale from whenever a
## given worker's loop started. First-pass curve, not tuned via
## playtesting - a flatter or steeper falloff is a one-line change here if
## multi-builder sites end up feeling too strong/weak once played.
const CONSTRUCTION_MULTI_BUILDER_EXPONENT := 0.5

## Work-tick sound pools, from the Free Fantasy SFX Pack (sound/Free Fantasy
## SFX Pack By TomMusic/) - one gather_sound.play() call used a single
## generic resource_gain.wav for every gather/labor/training tick regardless
## of what kind of work it was; these replace it with the pack's own
## purpose-made sound where a genuinely relevant one exists (see
## _play_gather_sound/the five call sites in _run_generic_work_loop/
## _run_farm_loop/_run_lumberjack_loop/_run_training_loop). Each pool has
## several numbered variants specifically so repeated ticks don't play the
## identical sample back to back - _play_gather_sound picks one at random
## per call. DEFAULT_GATHER_SOUNDS (a "pool" of the original single file)
## covers every gather-tick call site with no relevant pack analog (Farm-
## family crops, Mill/Bakery/Brewery, Construction labor - this pack is
## combat/environment-themed, not farming/crafting-themed) rather than
## force-fitting an unrelated sound just to "replace everything" - see the
## "Implement Sounds from new sound pack" completion write-up for the full
## per-building mapping and why select_chime.wav/assign_task.wav (pure UI
## feedback, not diegetic action sounds) were left untouched too.
const DEFAULT_GATHER_SOUNDS: Array[AudioStream] = [
	preload("res://sound/resource_gain.wav"),
]
const CHOP_SOUNDS: Array[AudioStream] = [
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Chopping and Mining/chop 1.ogg"),
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Chopping and Mining/chop 2.ogg"),
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Chopping and Mining/chop 3.ogg"),
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Chopping and Mining/chop 4.ogg"),
]
## Also used for Brickmaker (shares _run_farm_loop with Farm/Workshop, but
## its input is stone, unlike the others - see the branch in that loop) -
## the pack has no dedicated "crafting"/"forge" sound, and a striking-rock
## sound is a closer fit for turning stone into brick than the generic
## default.
const MINE_SOUNDS: Array[AudioStream] = [
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Chopping and Mining/mine 1.ogg"),
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Chopping and Mining/mine 2.ogg"),
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Chopping and Mining/mine 3.ogg"),
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Chopping and Mining/mine 4.ogg"),
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Chopping and Mining/mine 5.ogg"),
]
const SWORD_DRILL_SOUNDS: Array[AudioStream] = [
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Attacks/Sword Attacks Hits and Blocks/Sword Attack 1.ogg"),
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Attacks/Sword Attacks Hits and Blocks/Sword Attack 2.ogg"),
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Attacks/Sword Attacks Hits and Blocks/Sword Attack 3.ogg"),
]
const BOW_DRILL_SOUNDS: Array[AudioStream] = [
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Attacks/Bow Attacks Hits and Blocks/Bow Attack 1.ogg"),
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Attacks/Bow Attacks Hits and Blocks/Bow Attack 2.ogg"),
]
const SPELL_DRILL_SOUNDS: Array[AudioStream] = [
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Spells/Spell Impact 1.ogg"),
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Spells/Spell Impact 2.ogg"),
	preload("res://sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Spells/Spell Impact 3.ogg"),
]
## Flavor "drill" amount shown in a TrainingGround worker's gather feedback
## (see _run_training_loop) - purely cosmetic, nothing accumulates it
## toward a target the way ConstructionSite.labor_completed does, since
## training has no "finished" state. Same value as CONSTRUCTION_LABOR_PER_
## TICK for consistency, not because the two are mechanically linked.
const TRAINING_DRILL_PER_TICK := 1.0
## "speed" and "strength" are universal skills every citizen trains just by
## moving/carrying, regardless of what post (if any) they're assigned to -
## unlike XP_PER_GATHER's per-tick skills, which only train while actively
## working a post. Scaled by duration (not a flat per-move amount) so xp/
## real-time-spent-moving stays roughly constant regardless of level: a
## faster mover finishes each trip sooner but makes proportionally more
## trips in the same time, rather than snowballing - the same "reward time,
## not output" principle XP_PER_GATHER already follows, applied to movement.
## Picked to land in the same rough xp/sec ballpark as XP_PER_GATHER's
## while-working rate (4.0 per ~1.5s tick) - a first pass, not tuned via
## playtesting.
const SPEED_XP_PER_SECOND := 2.5

@export var data: CharacterData
var assigned_post: Node = null
var is_selected := false

## Human-readable summary of what this citizen is doing right now - shown
## on their skill panel (see SkillPanel.open_for) as a point-in-time
## snapshot at the moment they're clicked, not live-updated while the panel
## stays open (matches the panel's existing "view-only" design - re-click
## for a fresh read, same as every other field there). Set at each
## meaningfully distinct phase of whichever work/haul loop is currently
## running - see _run_hauler_loop/_execute_haul_job and each _run_*_loop
## for exactly where.
var current_task := "Idle"

@onready var label: Label = $Label
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var selection_outline: Sprite2D = $SelectionOutline
@onready var select_sound: AudioStreamPlayer2D = $SelectSound
@onready var assign_sound: AudioStreamPlayer2D = $AssignSound
@onready var gather_sound: AudioStreamPlayer2D = $GatherSound
@onready var level_up_sound: AudioStreamPlayer2D = $LevelUpSound
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var _base_position: Vector2
var _home_position: Vector2
var _move_tween: Tween
var _scale_tween: Tween
var _bob_phase := randf() * TAU

## Drives both the Farm and LumberCamp work loops (_run_farm_loop /
## _run_lumberjack_loop) - only one is ever active per character. Bumping
## _work_session cancels whichever is running, the same way the old
## lumberjack-only version worked.
var _work_active := false
var _work_session := 0
var _claimed_tree: WorldTree = null

## Time left until this worker's current production tick fires - see
## _wait_for_tick's own doc comment for why this exists (saving/restoring
## it is what stops every worker from resyncing onto the same tick after a
## load).
var _tick_remaining: float = 0.0


## Row 3 of the Tiny Pixel Art Entities sheet (the plain, unhelmeted
## swordsman) - see combat_unit.gd's UNIT_SPRITE_ROW doc comment for why
## this is built fresh in code rather than loaded from a saved
## SpriteFrames.tres (a hand-authored one silently lost its atlas
## reference the first time the editor re-saved it - only villager.tres
## survived that, because Character.tscn keeps it "alive" through normal
## editor use, and even that's not worth relying on).
const ENTITIES_SHEET := preload("res://art/Tiny Pixel Art/IsometricTRPGAssetPack_Entities.png")
const VILLAGER_ROW := 3


func _ready() -> void:
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_base_position = position
	_home_position = position
	selection_outline.modulate.a = 0.0
	sprite.sprite_frames = _build_sprite_frames(VILLAGER_ROW)
	sprite.play("walk")
	label.modulate.a = 0.0
	_update_label()
	if not assigned_post:
		_start_hauling()


func _process(delta: float) -> void:
	_bob_phase += delta * BOB_SPEED
	position = _base_position + Vector2(0, sin(_bob_phase) * BOB_AMPLITUDE)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		handle_click()


## The actual "this character was clicked" effect, split out of
## _on_input_event so Base's x-ray click-priority override (see its _input()
## doc comment) can trigger the exact same selection behavior when it
## manually picks this character out from underneath an occluding building,
## instead of duplicating these two lines at both call sites.
func handle_click() -> void:
	select_sound.play()
	clicked.emit(self)


func _on_mouse_entered() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.25, 1.25, 1.25), 0.12)


func _on_mouse_exited() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


## The floating name/title label only shows while this citizen is selected
## (whatever selected them - a mouse click today, some other trigger down
## the line) - per an explicit request, rather than persistently floating
## over every citizen at once. Faded alongside the same selection outline,
## same duration, so both read as one "you've selected this citizen" cue.
func set_selected(value: bool) -> void:
	is_selected = value
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(selection_outline, "modulate:a", 1.0 if value else 0.0, 0.15)
	tween.tween_property(label, "modulate:a", 1.0 if value else 0.0, 0.15)


## Called by Base when this citizen departs the settlement for good
## (sustained low happiness). Unassigns from any post and stops every
## active coroutine so none of them try to touch this node after Base
## frees it - deliberately not routed through assign_to(null), which would
## also kick off a pointless idle-hauling session and replay assignment
## juice (sound/tween) right before the node disappears.
func leave() -> void:
	if assigned_post:
		assigned_post.remove_worker()
		assigned_post = null
	_stop_work()


## Snaps to `pos` immediately, cancelling any in-flight move tween - used
## only by Base._restore_characters, right after assign_to() (which already
## started this character's restored work loop and its own initial
## _move_to toward the post), to put a loaded citizen exactly where they
## were saved rather than at their post/home position. The just-restarted
## loop wasn't told which step it was on when the save happened, so it
## just resumes from here as if it always started at this exact spot -
## e.g. if a haul was in progress, its next _move_to naturally continues
## from here rather than restarting from the post.
func snap_to_position(pos: Vector2) -> void:
	if _move_tween:
		_move_tween.kill()
	_base_position = pos
	position = pos


## `grant_move_xp` is false only when Base._restore_characters is about to
## override this call's own placement with snap_to_position() right after -
## see _move_to's doc comment for why that move shouldn't earn speed xp.
func assign_to(post: Node, grant_move_xp: bool = true) -> void:
	if assigned_post:
		assigned_post.remove_worker()
	_stop_work()
	assigned_post = post
	if post:
		post.add_worker()
		_move_to(post.get_worker_spot(), grant_move_xp)
		_start_work(post)
	else:
		_move_to(_home_position, grant_move_xp)
		_start_hauling()
	_update_label()
	_punch()
	assign_sound.play()


## `grant_xp` is false only for Base._restore_characters' initial
## assign_to() call on load - that move is immediately overridden by
## snap_to_position() right after (to place a loaded citizen exactly where
## they were saved, not at their post/home spot), so the "movement" here
## never actually happens and shouldn't earn speed xp. Without this, every
## quickload would hand every restored citizen a free chunk of speed xp
## (at least MIN_MOVE_DURATION's worth, more for a citizen far from their
## post) for a tween that gets killed before it ever plays - repeatable
## indefinitely via F9 spam, defeating the "reward time spent moving, not
## just calling _move_to" principle SPEED_XP_PER_SECOND's doc comment
## already establishes.
##
## Nav-agent-driven (see Base._rebake_navigation/WorldGrid.occupancy_changed
## for the town's navmesh) rather than a single straight-line Tween - a
## citizen now actually routes around buildings/trees instead of cutting
## through them. Static obstacle avoidance only (Character.tscn's
## NavigationAgent2D has avoidance_enabled = false) - unlike combat's
## RVO-driven CombatUnit, citizens don't dodge each other, only the map's
## fixed obstacles, per an explicit scoping decision to keep this port
## simpler than the battle sandbox's.
##
## This is what makes every one of this function's ~9 call sites able to
## just `await _move_to(...)` directly (no wrapping `get_tree().create_
## timer(...).timeout` the way the old fixed-duration-return version
## needed) - a real nav path's true travel time can't be known up front the
## way straight-line distance/speed could, so this function itself is now
## the awaitable, only returning once the citizen has actually arrived.
## MIN_MOVE_DURATION is still a floor (holds position a few extra frames
## after physically arriving, for a very short hop, so it never reads as an
## instant teleport) - MAX_MOVE_DURATION is no longer a hard cap on how long
## a trip can *take* (a genuinely long haul now really does take longer,
## correctly routing around obstacles instead of secretly speeding up to
## make an old artificial deadline), only a cap on how much of it counts
## toward speed xp, preserving the old per-trip xp ceiling without risking
## stranding a citizen mid-detour by force-stopping them short of the target.
func _move_to(target: Vector2, grant_xp: bool = true) -> void:
	if _move_tween:
		_move_tween.kill()
		_move_tween = null
	var speed_multiplier := data.get_skill_multiplier("speed") if data else 1.0
	var move_speed := MOVE_SPEED * speed_multiplier
	nav_agent.target_position = target
	var elapsed := 0.0
	## Hard escape hatch, not just a "typical trip" bound - a target outside
	## the baked navmesh (off the ground entirely, or unreachable for any
	## other reason) leaves is_navigation_finished() permanently false, and
	## without this the loop below would await forever, freezing this
	## citizen's whole work loop (verified: reproduced a real hang in
	## testing before this existed). Generous on purpose since a legitimate
	## long haul across the whole map can genuinely take this long now that
	## MAX_MOVE_DURATION no longer caps physical trip time (see this
	## function's own doc comment) - this is only meant to catch the
	## pathological "never going to finish" case, not cut a real walk short.
	const MOVE_HANG_SAFETY_SECONDS := 60.0
	while not nav_agent.is_navigation_finished() and elapsed < MOVE_HANG_SAFETY_SECONDS:
		var delta := get_process_delta_time()
		var next_pos: Vector2 = nav_agent.get_next_path_position()
		var direction := _base_position.direction_to(next_pos)
		_base_position += direction * move_speed * delta
		if absf(direction.x) > 0.01:
			sprite.flip_h = direction.x < 0.0
		elapsed += delta
		## This character can be leave()'d + queue_free()'d (departure) while
		## this coroutine is suspended on the await below - queue_free() is
		## deferred, so the node is still fully valid and callable right up
		## until the moment it actually exits the tree, at which point
		## get_tree() starts throwing "Parameter data.tree is null." instead
		## of returning a SceneTree. Bailing here rather than letting that
		## happen is what actually stops this loop; the caller's own
		## `session != _work_session` checks (bumped by leave()'s _stop_work)
		## can't run until this coroutine resumes and reaches them, which is
		## exactly what this guard preempts.
		if not is_inside_tree():
			return
		await get_tree().process_frame
	while elapsed < MIN_MOVE_DURATION:
		elapsed += get_process_delta_time()
		if not is_inside_tree():
			return
		await get_tree().process_frame
	if grant_xp:
		_gain_skill_xp("speed", SPEED_XP_PER_SECOND * minf(elapsed, MAX_MOVE_DURATION))


func _punch() -> void:
	if _scale_tween:
		_scale_tween.kill()
	scale = Vector2(1.2, 1.2)
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Only name + title are shown in-world (see set_selected for why they only
## show at all while this citizen is selected) - the old third "(Hauling)" /
## "(Lumber Camp · Lv 3)" status line was removed per an earlier explicit
## request to declutter floating citizen text (name/title/xp-and-loot
## feedback stay, everything else goes). That status is still fully
## knowable - it's just not shown here - via the (unchanged) skill panel on
## click.
func _update_label() -> void:
	if not data:
		return
	var title := SkillTitles.get_title(data, _current_skill_id())
	label.text = "%s\n%s" % [data.character_name, title]


## Maps the current assignment to the skill it trains. Empty string for no
## assignment (unassigned citizens haul instead).
func _current_skill_id() -> String:
	if assigned_post and assigned_post.has_method("get_skill_id"):
		return assigned_post.get_skill_id()
	return ""


## Grants xp toward `skill_id` and fires level-up feedback if it crossed a
## threshold. Safe to call every gather tick - most calls won't level up.
func _gain_skill_xp(skill_id: String, amount: float) -> void:
	if not data:
		return
	var old_level := data.get_skill_level(skill_id)
	data.add_skill_xp(skill_id, amount)
	var new_level := data.get_skill_level(skill_id)
	if new_level > old_level:
		_on_skill_level_up()


## Dedicated LevelUpSound (Level_up_fireworks.ogg) rather than reusing
## assign_sound the way this used to - that meant a level-up sounded
## identical to an ordinary job (re)assignment, with nothing distinguishing
## the moment a citizen actually got better at their skill.
func _on_skill_level_up() -> void:
	_punch()
	_update_label()
	level_up_sound.play()


## Floating "+1.2 Food  +4 xp" feedback for a single gather tick - see
## GatherFeedback.spawn's doc comment. get_parent() is Base itself (every
## Character is a direct child of it, per CLAUDE.md's y-sort convention),
## so `position` is already in the right local coordinate space with no
## global/local conversion needed.
func _show_gather_feedback(resource_type: String, amount: float, xp: float) -> void:
	GatherFeedback.spawn(get_parent(), position, resource_type, amount, xp)


## Picks a random variant from `pool` (see the *_SOUNDS constants above) and
## plays it through the shared GatherSound player, rather than always
## replaying the same sample - reuses the one player node for every
## gather/labor/training tick instead of adding a dedicated
## AudioStreamPlayer2D per sound category.
func _play_gather_sound(pool: Array[AudioStream]) -> void:
	gather_sound.stream = pool[randi() % pool.size()]
	gather_sound.play()


## How much of a post's resource_type/input_resource this specific character
## can move in one trip - post.carry_limit (the building's own stat) scaled
## by this character's strength. Used everywhere a haul function decides how
## much to pick up/carry out/hold before hauling, so a stronger character
## genuinely moves more per trip instead of strength being purely cosmetic.
func _carry_capacity(post: Workstation) -> float:
	return post.carry_limit * (data.get_skill_multiplier("strength") if data else 1.0)


func _start_work(post: Node) -> void:
	_work_active = true
	_work_session += 1
	if post is Farm or post is Brickmaker or post is Workshop:
		_run_farm_loop(post, _work_session)
	elif post is LumberCamp:
		_run_lumberjack_loop(post, _work_session)
	elif post is ConstructionSite:
		_run_construction_loop(post, _work_session)
	elif post is TrainingGround:
		_run_training_loop(post, _work_session)
	elif post is Workstation:
		_run_generic_work_loop(post, _work_session)


func _stop_work() -> void:
	_work_active = false
	_work_session += 1
	if _claimed_tree and is_instance_valid(_claimed_tree):
		_claimed_tree.claimed = false
	_claimed_tree = null


func _start_hauling() -> void:
	_work_active = true
	_work_session += 1
	_run_hauler_loop(_work_session)


## Shared by every work loop's production-tick wait (_run_generic_work_loop/
## _run_construction_loop/_run_training_loop/_run_farm_loop/
## _run_lumberjack_loop) in place of a bare `await get_tree().create_
## timer(interval).timeout` - functionally the same wait, but also keeps
## _tick_remaining in sync so a save mid-cycle captures the real countdown
## instead of losing it. Without this, every restored worker's loop would
## start its very first wait fresh at the *full* interval, so an entire
## town of farmers/lumberjacks/etc. would end up perfectly resynced (all
## producing on the same tick from that moment on) purely as an artifact of
## when the save happened to load - something that never occurs during
## continuous play, since each worker's loop naturally starts at whatever
## moment they were individually assigned.
##
## If _tick_remaining is already > 0 when called, that's the one-time
## resume case (Base._restore_characters sets it right before assign_to()
## restarts this loop) - waits that long instead of the full interval, then
## the loop is back to normal cadence for every tick after. Decrements via
## a manual per-frame loop (get_process_delta_time(), same pattern _move_to
## already uses) rather than a parallel _process() callback specifically so
## the countdown only ever ticks down while actually inside this wait, not
## during whatever haul/move detour a loop takes before reaching it.
## Guards is_inside_tree() as every other awaited tree signal in this file
## does (see _move_to's own doc comment for the departure-mid-await race
## this prevents).
func _wait_for_tick(interval: float) -> void:
	var wait_time: float = _tick_remaining if _tick_remaining > 0.0 else interval
	_tick_remaining = wait_time
	while _tick_remaining > 0.0:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		_tick_remaining -= get_process_delta_time()
	_tick_remaining = 0.0


## An idle character isn't wasted - it either carries a workstation's
## output_buffer to the stockpile, or carries a needed input from the
## stockpile out to a workstation that's running short (e.g. wood to a
## Farm), whichever job is currently more valuable, one trip at a time.
## Reuses the workstation's own carry_limit as the trip size rather than
## tracking a separate hauler-specific limit. Runs until reassigned
## (session changes) - including by another idle-hauling session, e.g.
## after a drag-and-drop back to no post.
func _run_hauler_loop(session: int) -> void:
	while _work_active and session == _work_session:
		var job := _find_haul_job()
		if job.is_empty():
			current_task = "Idle"
			if not is_inside_tree():
				return
			await get_tree().create_timer(IDLE_RETRY_DELAY).timeout
			continue
		if not await _execute_haul_job(job, session):
			return


## The actual pickup/delivery for a job from _find_haul_job - shared by
## _run_hauler_loop (an idle/unassigned citizen's whole job) and
## _assist_haul_or_wait (a dedicated worker helping out during a moment
## their own post has nothing for them to do). Returns false if a
## reassignment interrupted the trip.
func _execute_haul_job(job: Dictionary, session: int) -> bool:
	if job["type"] == "construction":
		current_task = "Delivering %s" % String(job["resource"]).capitalize()
		return await _deliver_construction_material(job["post"], session, job["resource"])

	var post: Workstation = job["post"]

	if job["type"] == "output":
		current_task = "Hauling %s" % post.resource_type.capitalize()
		await _move_to(post.get_worker_spot())
		if session != _work_session:
			return false
		if post.output_buffer < HAUL_MIN_THRESHOLD:
			return true
		return await _haul_to_stockpile(post, session, post.resource_type, "")
	else:
		current_task = "Delivering %s" % String(job["resource"]).capitalize()
		return await _deliver_to_post(post, session, job["resource"])


## Called from a dedicated work loop's own "blocked, nothing useful to do
## right now" moments (Farm waiting on an input restock, LumberCamp finding
## no available tree in range) instead of just standing around idle -
## looks for the single most valuable haul job across every post (the same
## search an idle/unassigned citizen already runs) and does it once before
## the caller re-checks its own post. Falls back to the same
## IDLE_RETRY_DELAY wait if there's nothing worth hauling either. Returns
## false if reassigned mid-trip.
func _assist_haul_or_wait(session: int) -> bool:
	var job := _find_haul_job()
	if job.is_empty():
		current_task = "Idle"
		if not is_inside_tree():
			return false
		await get_tree().create_timer(IDLE_RETRY_DELAY).timeout
		return session == _work_session
	return await _execute_haul_job(job, session)


## Construction material delivery always wins over routine output/input
## hauling - checked first, and returned immediately if found, rather than
## competing on "how much would this move" the way output/input do against
## each other below. A stalled construction site doesn't just mean one
## delivery is a little late (an already-working post's buffer can always
## wait for the next comparison); it means an entire job post's labor phase
## can never start, and a citizen who could be assigned to build it instead
## sits hauling forever (see _run_job_assignment - a post with 0 effective
## capacity because materials never finished arriving just never gets
## proposed to). A comparison-by-amount approach used to structurally lose
## to output/input hauling once the economy had a couple of active
## producers - construction's own per-trip amount is capped by carry
## capacity (~6-8 units), which routine output/input hauling regularly
## matches or exceeds once workstations are actually running, so
## construction almost never won the old comparison and buildings
## effectively never finished. Falls through to the old output/input
## comparison only when no construction site currently needs anything.
func _find_haul_job() -> Dictionary:
	var base := get_parent() as Base
	if not base:
		return {}

	var construction_job := _find_construction_haul_job(base)
	if not construction_job.is_empty():
		return construction_job

	var best_output: Workstation = null
	var best_output_amount := HAUL_MIN_THRESHOLD

	var best_input: Workstation = null
	var best_input_amount := HAUL_MIN_THRESHOLD
	var best_input_resource := ""

	for post in base.posts:
		if not (post is Workstation):
			continue

		if post.output_buffer > best_output_amount:
			best_output = post
			best_output_amount = post.output_buffer

		var resource: String = post.get_input_resource()
		if resource.is_empty():
			continue
		var deficit: float = _carry_capacity(post) - post.input_buffer
		if deficit > best_input_amount and GameState.resources.get(resource, 0.0) > 0.0:
			best_input = post
			best_input_amount = deficit
			best_input_resource = resource

	if best_output and (not best_input or best_output_amount >= best_input_amount):
		return {"post": best_output, "type": "output"}
	if best_input:
		return {"post": best_input, "type": "input", "resource": best_input_resource}
	return {}


## Picks the *smallest* outstanding construction-material need across every
## in-progress Base.construction_sites entry (a site can need several
## different resources at once - see ConstructionSite.materials_needed),
## capped by this character's own _carry_capacity same as any other haul
## amount, so a single trip can fully clear it when possible. Deliberately
## smallest-first, not largest-first (an earlier version of this function
## picked whichever need was biggest) - per an explicit diagnosis: with
## several sites competing for a resource that's actually scarce (own
## wood insufficient to cover every site's total cost at once - see
## GameState.DEFAULT_RESOURCES's wood comment for the exact scenario this
## was built for), largest-first systematically drains the stockpile into
## whichever site is *most* expensive before any cheaper site gets
## anything, which can permanently strand a cheap-but-critical site (e.g.
## a Lumber Camp, the only source of *more* wood) with a partial delivery
## it can never complete - headless-verified as a real, permanent soft-
## lock: 200+ simulated seconds with zero further progress, every haul
## trip re-confirming the same starved site. Smallest-first instead
## finishes cheap sites fast (unlocking whatever they produce sooner) and
## never leaves a small need dangling while resources are funneled into a
## big one. Returns {} if nothing clears HAUL_MIN_THRESHOLD or the
## stockpile has none of whatever's needed to bring. Split out of
## _find_haul_job so it can be checked first, unconditionally, ahead of
## routine output/input hauling - see that function's doc comment for why.
func _find_construction_haul_job(base: Base) -> Dictionary:
	var best_site: ConstructionSite = null
	var best_amount := INF
	var best_resource := ""

	for site in base.construction_sites:
		if not is_instance_valid(site):
			continue
		for resource_name in site.materials_needed:
			var needed: float = minf(site.materials_needed[resource_name], _carry_capacity(site))
			if needed < HAUL_MIN_THRESHOLD or GameState.resources.get(resource_name, 0.0) <= 0.0:
				continue
			if needed < best_amount:
				best_site = site
				best_amount = needed
				best_resource = resource_name

	if best_site:
		return {"post": best_site, "type": "construction", "resource": best_resource}
	return {}


## Walks from wherever the character currently is to whichever registered
## stockpile (the Outpost Hall, or a Storage Facility) is nearest, drops
## everything in post.output_buffer into `drop_resource`, then
## - if `pickup_resource` is non-empty (Farm's own dedicated worker only; a
## generalist hauler delivers input via _deliver_to_post instead) -
## withdraws enough of it into post.input_buffer to top the buffer up to
## this character's _carry_capacity, further capped by what the stockpile
## actually has. Leaves the character standing at the stockpile - it does
## NOT walk back to `post` afterward, since not every caller wants that (a
## lumberjack should head straight to the next tree, not detour back through
## the camp first; a farm worker needs to return to keep producing and
## handles that itself after calling this). Returns false if a reassignment
## (session change) interrupted the trip, telling the caller to stop rather
## than keep going. Grants strength xp once per trip that actually moved
## anything (either leg), not per resource unit - see SPEED_XP_PER_SECOND's
## doc comment for why xp scales with time/frequency of the activity rather
## than with quantity carried.
func _haul_to_stockpile(post: Workstation, session: int, drop_resource: String, pickup_resource: String) -> bool:
	await _move_to(WorldGrid.nearest_stockpile(global_position))
	if session != _work_session:
		return false

	var carried := false
	if post.output_buffer > 0.0:
		GameState.add_resource(drop_resource, post.output_buffer)
		post.output_buffer = 0.0
		carried = true

	if not pickup_resource.is_empty():
		var take: float = minf(_carry_capacity(post) - post.input_buffer, GameState.resources.get(pickup_resource, 0.0))
		if take > 0.0:
			GameState.spend({pickup_resource: take})
			post.input_buffer += take
			carried = true

	if carried:
		_gain_skill_xp("strength", XP_PER_GATHER)

	if not is_inside_tree():
		return false
	await get_tree().create_timer(STOCKPILE_PAUSE).timeout
	return session == _work_session


## The reverse of _haul_to_stockpile: walks to the stockpile first,
## withdraws up to this character's _carry_capacity of `resource` (capped by
## post's remaining input space and what the stockpile actually has), then walks
## the resource out to `post` and deposits it into input_buffer. Used by
## idle haulers delivering input a workstation needs; a dedicated worker
## (e.g. Farm's own) still self-services its own pickup via
## _haul_to_stockpile's pickup_resource param instead (that one's a single
## atomic block with no travel gap, so it can't double-count the way this
## multi-leg trip could - see below). Returns false if a reassignment
## interrupted the trip.
func _deliver_to_post(post: Workstation, session: int, resource: String) -> bool:
	await _move_to(WorldGrid.nearest_stockpile(global_position))
	if session != _work_session:
		return false

	var take: float = minf(_carry_capacity(post) - post.input_buffer, GameState.resources.get(resource, 0.0))
	if take <= 0.0:
		return true
	GameState.spend({resource: take})

	if not is_inside_tree():
		GameState.add_resource(resource, take)
		return false
	await get_tree().create_timer(STOCKPILE_PAUSE).timeout
	if session != _work_session:
		# Carrying `take` and about to be reassigned - hand it back rather
		# than letting it vanish.
		GameState.add_resource(resource, take)
		return false

	await _move_to(post.get_worker_spot())
	if session != _work_session:
		GameState.add_resource(resource, take)
		return false

	# Re-check post.input_buffer now, not the stale reading from when `take`
	# was computed - another hauler (or the post's own dedicated worker) may
	# have topped it up while this trip was in transit. Only unload what
	# still fits, against THIS character's own _carry_capacity again (not a
	# fixed post-level cap), so a strong hauler isn't punished with a refund
	# just for exceeding the post's base carry_limit; refund the rest to the
	# stockpile instead of overshooting or destroying it. Without this,
	# multiple idle haulers converging on the same starved post all carry a
	# full load computed against the same "empty" snapshot and stack past
	# capacity on arrival.
	var space: float = maxf(0.0, _carry_capacity(post) - post.input_buffer)
	var delivered: float = minf(take, space)
	post.input_buffer += delivered
	if delivered < take:
		GameState.add_resource(resource, take - delivered)
	if delivered > 0.0:
		_gain_skill_xp("strength", XP_PER_GATHER)
	return true


## Same shape as _deliver_to_post, but targets a ConstructionSite's
## materials_needed Dictionary entry for `resource` instead of a
## Workstation's single input_buffer - a site can need several different
## resources at once (e.g. a Storage Facility needs wood AND stone), so
## delivery is per-resource rather than a single float. Erases the
## resource's entry once fully delivered (not just left at 0.0 - see
## ConstructionSite.materials_are_ready()) and emits materials_ready once
## every entry is gone, which Base listens for to make the site eligible
## for automatic labor assignment. Same re-check-on-arrival/refund-surplus
## safety as _deliver_to_post, for the same reason (multiple haulers
## converging on the same site from an identical "still needed" snapshot).
func _deliver_construction_material(site: ConstructionSite, session: int, resource: String) -> bool:
	await _move_to(WorldGrid.nearest_stockpile(global_position))
	if session != _work_session:
		return false

	var needed: float = site.materials_needed.get(resource, 0.0)
	var take: float = minf(minf(_carry_capacity(site), needed), GameState.resources.get(resource, 0.0))
	if take <= 0.0:
		return true
	GameState.spend({resource: take})

	if not is_inside_tree():
		GameState.add_resource(resource, take)
		return false
	await get_tree().create_timer(STOCKPILE_PAUSE).timeout
	if session != _work_session:
		GameState.add_resource(resource, take)
		return false

	await _move_to(site.get_worker_spot())
	if session != _work_session:
		GameState.add_resource(resource, take)
		return false

	if not is_instance_valid(site):
		GameState.add_resource(resource, take)
		return true

	var remaining: float = site.materials_needed.get(resource, 0.0)
	var delivered: float = minf(take, remaining)
	if delivered > 0.0:
		site.materials_needed[resource] -= delivered
		if site.materials_needed[resource] <= 0.0:
			site.materials_needed.erase(resource)
			site.refresh_label()
			if site.materials_are_ready():
				site.materials_ready.emit()
	if delivered < take:
		GameState.add_resource(resource, take - delivered)
	if delivered > 0.0:
		_gain_skill_xp("strength", XP_PER_GATHER)
	return true


## The plain-labor case: no input to manage, no special walking pattern
## (LumberCamp) - just produce output_per_tick every work_interval and haul
## it out once this character's _carry_capacity is hit (a stronger worker
## accumulates more before a trip is worth making). Used for any Workstation
## that isn't a Farm or LumberCamp (e.g. StoneMine). Runs until reassigned.
func _run_generic_work_loop(post: Workstation, session: int) -> void:
	while _work_active and session == _work_session:
		if post.output_buffer >= _carry_capacity(post):
			current_task = "Hauling %s" % post.resource_type.capitalize()
			if not await _haul_to_stockpile(post, session, post.resource_type, ""):
				return
			## _haul_to_stockpile leaves the character standing at the
			## stockpile - fine for a lumberjack (heads to a tree next
			## anyway) but production for this generic case only happens
			## back at the post, same as Farm's loop already accounts for.
			## Without this, a Stone Mine (or any other generic post)
			## worker would get stranded at the stockpile forever after
			## their first haul trip, "producing" from there indefinitely.
			await _move_to(post.get_worker_spot())
			if session != _work_session:
				return
			continue

		current_task = "Gathering %s" % post.resource_type.capitalize()
		await _wait_for_tick(post.work_interval)
		if session != _work_session:
			return

		var multiplier: float = data.get_skill_multiplier(post.get_skill_id())
		var amount: float = post.output_per_tick * multiplier * GameState.happiness_output_multiplier
		post.output_buffer += amount
		## _run_generic_work_loop is StoneMine's loop - every other
		## Workstation subclass dispatches to its own dedicated loop (see
		## _start_work) - so MINE_SOUNDS is always the right pool here,
		## with no branching needed the way _run_farm_loop's shared call
		## site (Farm/Brickmaker/Workshop) needs.
		_play_gather_sound(MINE_SOUNDS)
		var xp: float = amount * XP_PER_RESOURCE_UNIT
		_gain_skill_xp(post.get_skill_id(), xp)
		_show_gather_feedback(post.resource_type, amount, xp)


## A construction site is only ever assigned to a worker once its materials
## phase is already done (see ConstructionSite.materials_ready/Base._on_
## construction_materials_ready) - this loop is purely the labor phase, no
## haul cycle at all (nothing here is a resource that needs carrying to the
## stockpile, "labor" just represents time spent). Every work_interval,
## adds CONSTRUCTION_LABOR_PER_TICK * this worker's construction skill
## multiplier * the settlement's happiness multiplier * a multi-builder
## effectiveness factor (see CONSTRUCTION_MULTI_BUILDER_EXPONENT - 1.0
## whenever this worker is the only one on the site) to labor_completed -
## same "skill/happiness scale output, not a separate input" pattern every
## other work loop already follows, just with no input side to begin with.
## Once labor_completed reaches labor_required, tells the site it's done
## and stops - Base's construction_complete handler takes it from there
## (including reassigning this character via the next job-assignment pass).
func _run_construction_loop(site: ConstructionSite, session: int) -> void:
	while _work_active and session == _work_session:
		current_task = "Building"
		await _wait_for_tick(site.work_interval)
		if session != _work_session:
			return
		if not is_instance_valid(site):
			return

		var multiplier: float = data.get_skill_multiplier(site.get_skill_id())
		var effectiveness: float = 1.0 / pow(maxf(site.active_workers, 1), CONSTRUCTION_MULTI_BUILDER_EXPONENT)
		var gain: float = CONSTRUCTION_LABOR_PER_TICK * multiplier * GameState.happiness_output_multiplier * effectiveness
		site.labor_completed += gain
		_play_gather_sound(DEFAULT_GATHER_SOUNDS)
		_gain_skill_xp(site.get_skill_id(), XP_PER_GATHER)
		_show_gather_feedback("labor", gain, XP_PER_GATHER)
		site.refresh_label()

		if site.labor_completed >= site.labor_required:
			site.mark_complete()
			return


## Trains a TrainingGround's combat skill (melee_combat/archery/
## spellcasting) with flat per-tick xp, same "reward time worked, not
## output" principle every other work loop follows - but with no input/
## output/haul cycle at all, same shape as _run_construction_loop's labor-
## only loop, except it never completes: a TrainingGround has no
## labor_required-style target to reach, a citizen just keeps training for
## as long as they're assigned here (this is the "convert a citizen into a
## soldier" step - see training_ground.gd's doc comment). Feeding the
## resulting skill level into CombatUnit stats is a separate, not-yet-built
## piece (see combat_unit.gd's own doc comment) - this loop's whole job is
## making that trained level exist and be visible (title/skill panel) as xp
## accrues here.
func _run_training_loop(post: Workstation, session: int) -> void:
	while _work_active and session == _work_session:
		current_task = "Training"
		await _wait_for_tick(post.work_interval)
		if session != _work_session:
			return

		var multiplier: float = data.get_skill_multiplier(post.get_skill_id())
		var drill: float = TRAINING_DRILL_PER_TICK * multiplier * GameState.happiness_output_multiplier
		## Barracks/Archery Range/Mage Tower train melee_combat/archery/
		## spellcasting respectively (BuildingCatalog's skill_id per entry) -
		## picks the matching drill sound rather than one generic tick, same
		## reasoning as _run_farm_loop's Brickmaker branch below.
		match post.get_skill_id():
			"melee_combat":
				_play_gather_sound(SWORD_DRILL_SOUNDS)
			"archery":
				_play_gather_sound(BOW_DRILL_SOUNDS)
			"spellcasting":
				_play_gather_sound(SPELL_DRILL_SOUNDS)
			_:
				_play_gather_sound(DEFAULT_GATHER_SOUNDS)
		_gain_skill_xp(post.get_skill_id(), XP_PER_GATHER)
		_show_gather_feedback("training", drill, XP_PER_GATHER)


## Converts input_resource into resource_type: consumes input_per_tick from
## input_buffer, produces output_per_tick into output_buffer, every
## work_interval. Hauls to the stockpile whenever the input buffer can't
## cover the next tick's cost, or the output buffer is full - whichever
## comes first, so a single trip handles both directions when possible.
## Despite the parameter name, `post` covers every converter-shaped
## building - the raw-crop Farm-class buildings (see farm.gd), Brickmaker
## (see brickmaker.gd), and Workshop (Mill/Bakery/Brewery - see
## workshop.gd), all of which share this one loop by structural typing
## alone (input_per_tick/input_resource live on Workstation itself, not
## Farm) without joining the Farm-family crop-panel retool system, which
## only Farm-class buildings are part of. Runs until reassigned (session
## changes).
func _run_farm_loop(post: Workstation, session: int) -> void:
	while _work_active and session == _work_session:
		## Skill only scales output, not input_needed - a higher-level
		## worker converts the same input into more output (a genuine
		## efficiency gain), rather than just moving proportionally more
		## of both through the post at the same ratio. Speed/strength are
		## the deliberate exception (Character.WATER_FARM_OUTPUT_BONUS's
		## sibling doc comments) - they scale movement/carry capacity
		## directly instead of a conversion ratio, since there's no
		## "input" for them to hold fixed.
		var multiplier: float = data.get_skill_multiplier(post.get_skill_id())
		var input_needed: float = post.input_per_tick

		if post.input_buffer < input_needed or post.output_buffer >= _carry_capacity(post):
			current_task = "Hauling %s" % post.resource_type.capitalize()
			if not await _haul_to_stockpile(post, session, post.resource_type, post.get_input_resource()):
				return
			await _move_to(post.get_worker_spot())
			if session != _work_session:
				return
			if post.input_buffer < input_needed:
				# Stockpile didn't have enough input to fully restock -
				# help haul somewhere else useful in the meantime rather
				# than just standing around waiting.
				if not await _assist_haul_or_wait(session):
					return
				continue

		current_task = "Producing %s" % post.resource_type.capitalize()
		await _wait_for_tick(post.work_interval)
		if session != _work_session:
			return

		# Re-check right before consuming, not just before the wait above -
		# with two workers sharing one Farm-class post (allowed, same as
		# LumberCamp), both can pass the earlier gate while input_buffer is
		# still sufficient and then both sit through their own work_interval
		# wait before touching it. Consuming unconditionally here would let
		# both decrement, driving input_buffer negative. Skipping this cycle
		# is safe: the loop just comes back around and hauls more in.
		if post.input_buffer < input_needed:
			continue

		# Water's irrigation bonus is a Farm-specific (crop-growing) effect,
		# not a generic "any converter" one - gated on `post is Farm` so
		# neither Brickmaker nor Workshop (Mill/Bakery/Brewery) sharing this
		# loop also pick up a well bonus for masonry/milling/baking/brewing,
		# which wouldn't make sense. Mill/Bakery/Brewery used to get this
		# bonus back when they were Farm instances themselves - losing it is
		# an intended consequence of disassociating them into their own
		# Workshop class, not an oversight.
		var water_bonus: float = WATER_FARM_OUTPUT_BONUS if (post is Farm and GameState.has_water()) else 1.0
		post.input_buffer -= input_needed
		var amount: float = post.output_per_tick * multiplier * GameState.happiness_output_multiplier * water_bonus
		post.output_buffer += amount
		## Brickmaker shares this loop (see the class's own doc comment
		## above) but works stone, not a crop - MINE_SOUNDS fits it, not
		## the crop-family default.
		_play_gather_sound(MINE_SOUNDS if post is Brickmaker else DEFAULT_GATHER_SOUNDS)
		var xp: float = amount * XP_PER_RESOURCE_UNIT
		_gain_skill_xp(post.get_skill_id(), xp)
		_show_gather_feedback(post.resource_type, amount, xp)


## Walk to a nearby tree and chop it (accumulating wood in the camp's
## output_buffer, not straight into the resource pool) until either the
## tree runs out or the buffer hits this character's _carry_capacity,
## hauling a full buffer to the stockpile whenever it's ready. A tree that
## still has wood left when capacity is hit is released (not depleted) so
## it - or another worker - can pick it back up later; a stronger
## lumberjack carries more per tree visit before that happens. Before each
## chopping trip, tops up the local forest toward camp.optimal_tree_count if
## it's short - this is a shared area target, not a per-worker replant
## quota, so it plants whether or not this worker is the one who did the
## chopping. Runs until reassigned (session changes).
func _run_lumberjack_loop(camp: LumberCamp, session: int) -> void:
	while _work_active and session == _work_session:
		if camp.output_buffer >= _carry_capacity(camp):
			current_task = "Hauling wood"
			if not await _haul_to_stockpile(camp, session, "wood", ""):
				return
			continue

		var camp_cell: Vector2 = WorldGrid.local_to_grid(camp.get_worker_spot())

		if WorldGrid.count_trees_near(camp_cell, camp.search_radius) < camp.optimal_tree_count:
			var plant_cell = WorldGrid.find_plantable_cell(camp_cell, camp.search_radius)
			if plant_cell != null:
				current_task = "Planting tree"
				var target := WorldGrid.grid_to_local(Vector2(plant_cell.x, plant_cell.y))
				await _move_to(target)
				if session != _work_session:
					return
				WorldGrid.plant_tree(plant_cell, false)
				_punch()
				continue

		var tree: WorldTree = WorldGrid.find_available_tree(camp_cell, camp.search_radius)

		if not tree:
			# No tree in range right now - help haul somewhere else useful
			# in the meantime rather than just standing around waiting.
			if not await _assist_haul_or_wait(session):
				return
			continue

		tree.claimed = true
		_claimed_tree = tree
		current_task = "Walking to tree"
		await _move_to(tree.global_position)
		if session != _work_session:
			return

		while _work_active and session == _work_session and is_instance_valid(tree) and tree.wood_remaining > 0.0 and camp.output_buffer < _carry_capacity(camp):
			current_task = "Chopping tree"
			await _wait_for_tick(camp.chop_interval)
			if session != _work_session:
				return
			if not is_instance_valid(tree):
				break
			var gained: float = tree.harvest(camp.wood_per_chop)
			if gained > 0.0 and data:
				var amount: float = gained * data.get_skill_multiplier(camp.get_skill_id()) * GameState.happiness_output_multiplier
				camp.output_buffer += amount
				_play_gather_sound(CHOP_SOUNDS)
				var xp: float = amount * XP_PER_RESOURCE_UNIT
				_gain_skill_xp(camp.get_skill_id(), xp)
				_show_gather_feedback("wood", amount, xp)

		if is_instance_valid(tree) and tree.wood_remaining > 0.0:
			tree.claimed = false
		_claimed_tree = null


## CELL_W/CELL_H are the sheet's per-frame grid stride (used to locate a
## frame's column/row), not its content size - every frame in this sheet
## only draws into a small part of its 16x17 cell (measured: content never
## exceeds local x=[3,15], y=[2,13] across every row this game uses, villager
## included). FRAME_INSET/FRAME_SIZE crop to that shared tight bounding box
## instead of the full padded cell, so `scale` maps onto actual drawn pixels
## - matching combat_unit.gd's identical crop (kept in lockstep since both
## draw from the same sheet's same grid). This alone doesn't change how big
## anything renders (scale times content-pixel-count is unaffected by how
## much transparent padding surrounded it) - it only makes the crop/anchor
## math well-defined for whatever scale gets chosen, here or later.
static func _build_sprite_frames(row_1indexed: int) -> SpriteFrames:
	const CELL_W := 16
	const CELL_H := 17
	const FRAME_INSET := Vector2(3, 2)
	const FRAME_SIZE := Vector2(12, 11)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"walk")
	frames.set_animation_loop(&"walk", true)
	frames.set_animation_speed(&"walk", 6.0)
	var y := (row_1indexed - 1) * CELL_H
	for col in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = ENTITIES_SHEET
		atlas.region = Rect2(col * CELL_W + FRAME_INSET.x, y + FRAME_INSET.y, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame(&"walk", atlas)
	return frames
