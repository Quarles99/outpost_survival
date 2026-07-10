extends Area2D
class_name Character

## Fired on every left-press, before it's known whether this becomes a plain
## click or a real drag — Base resolves that and calls back in accordingly.
signal drag_started(character: Character)

const BOB_AMPLITUDE := 2.5
const BOB_SPEED := 1.4
## Deliberately slow ("realistic travel time" over instant snapping) - a
## work post sitting a few tiles from the stockpile should read as a real
## walk, not a blip.
const MOVE_SPEED := 140.0
const MIN_MOVE_DURATION := 0.3
const MAX_MOVE_DURATION := 4.0
const IDLE_RETRY_DELAY := 2.5
const DRAG_SCALE := Vector2(1.15, 1.15)
## Flat xp granted per gather tick/chop, regardless of skill or output -
## xp is for time-worked, not scaled by level (which would make high levels
## snowball even faster on top of their output multiplier).
const XP_PER_GATHER := 4.0
## Brief hold at the stockpile while dropping off/picking up, so even a
## short haul doesn't read as an instant teleport-and-return.
const STOCKPILE_PAUSE := 0.3
## Idle haulers ignore a workstation buffer below this - not worth a whole
## round trip for a trickle.
const HAUL_MIN_THRESHOLD := 1.0

@export var data: CharacterData
var assigned_post: Node = null
var is_selected := false

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D
@onready var selection_outline: Sprite2D = $SelectionOutline
@onready var select_sound: AudioStreamPlayer2D = $SelectSound
@onready var assign_sound: AudioStreamPlayer2D = $AssignSound
@onready var gather_sound: AudioStreamPlayer2D = $GatherSound

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

var _is_dragging := false


func _ready() -> void:
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_base_position = position
	_home_position = position
	selection_outline.modulate.a = 0.0
	_update_label()
	if not assigned_post:
		_start_hauling()


func _process(delta: float) -> void:
	if _is_dragging:
		return
	_bob_phase += delta * BOB_SPEED
	position = _base_position + Vector2(0, sin(_bob_phase) * BOB_AMPLITUDE)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		select_sound.play()
		drag_started.emit(self)


func _on_mouse_entered() -> void:
	if _is_dragging:
		return
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.25, 1.25, 1.25), 0.12)


func _on_mouse_exited() -> void:
	if _is_dragging:
		return
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func set_selected(value: bool) -> void:
	is_selected = value
	var tween := create_tween()
	tween.tween_property(selection_outline, "modulate:a", 1.0 if value else 0.0, 0.15)


func assign_to(post: Node) -> void:
	if assigned_post:
		assigned_post.remove_worker()
	_stop_work()
	assigned_post = post
	if post:
		post.add_worker()
		_move_to(post.get_worker_spot() if post.has_method("get_worker_spot") else global_position)
		if post is Workstation:
			_start_work(post)
	else:
		_move_to(_home_position)
		_start_hauling()
	_update_label()
	_punch()
	assign_sound.play()


## Picked up by Base once a press crosses the drag threshold. The character's
## origin tracks the cursor directly via update_drag(); _process()'s idle bob
## is suspended for the duration so the two don't fight over `position`.
func start_drag() -> void:
	_is_dragging = true
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	if _move_tween:
		_move_tween.kill()
	if _scale_tween:
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", DRAG_SCALE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func update_drag(global_pos: Vector2) -> void:
	if _is_dragging:
		global_position = global_pos


## Ends the drag and syncs _base_position to wherever it was dropped, so
## whatever runs next (assign_to's _move_to, or cancel_drag's) animates
## smoothly from the drop point instead of snapping back to a stale position.
## Kills/replaces the shared _scale_tween rather than starting an independent
## one, since assign_to's _punch() runs right after on a successful drop and
## would otherwise fight this tween over the same scale property.
func end_drag() -> void:
	_is_dragging = false
	_base_position = global_position
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if _scale_tween:
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Dropped somewhere invalid: settle back to the current assignment's spot
## without touching assigned_post/worker counts/lumberjack state, so an
## accidental drag-and-miss can't interrupt work in progress.
func cancel_drag() -> void:
	end_drag()
	var target := _home_position
	if assigned_post and assigned_post.has_method("get_worker_spot"):
		target = assigned_post.get_worker_spot()
	_move_to(target)


func _move_to(target: Vector2) -> float:
	if _move_tween:
		_move_tween.kill()
	var duration := clampf(_base_position.distance_to(target) / MOVE_SPEED, MIN_MOVE_DURATION, MAX_MOVE_DURATION)
	_move_tween = create_tween()
	_move_tween.tween_property(self, "_base_position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return duration


func _punch() -> void:
	if _scale_tween:
		_scale_tween.kill()
	scale = Vector2(1.2, 1.2)
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_label() -> void:
	if not data:
		return
	var status: String = assigned_post.display_name if assigned_post else "Hauling"
	var skill_id := _current_skill_id()
	if not skill_id.is_empty():
		status += " · Lv %d" % data.get_skill_level(skill_id)
	label.text = "%s\n(%s)" % [data.character_name, status]


## Maps the current assignment to the skill it trains. Empty string for no
## assignment or a post type that doesn't train anything (e.g. WallSegment).
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


func _on_skill_level_up() -> void:
	_punch()
	_update_label()
	assign_sound.play()


func _start_work(post: Node) -> void:
	_work_active = true
	_work_session += 1
	if post is Farm:
		_run_farm_loop(post, _work_session)
	elif post is LumberCamp:
		_run_lumberjack_loop(post, _work_session)
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
			await get_tree().create_timer(IDLE_RETRY_DELAY).timeout
			continue

		var post: Workstation = job["post"]

		if job["type"] == "output":
			await get_tree().create_timer(_move_to(post.get_worker_spot())).timeout
			if session != _work_session:
				return
			if post.output_buffer < HAUL_MIN_THRESHOLD:
				continue
			if not await _haul_to_stockpile(post, session, post.resource_type, ""):
				return
		else:
			if not await _deliver_to_post(post, session, job["resource"]):
				return


## Picks the single most valuable haul job across every Workstation post
## (found via Base.posts - Character is always a direct child of Base, see
## CLAUDE.md's y-sort notes): either hauling a post's output_buffer out to
## the stockpile, or delivering its get_input_resource() in from the
## stockpile. Compares the two kinds by how much they'd move (both are
## bounded by the same carry_limit in practice) and just takes the larger -
## not a sophisticated priority system, but enough to stop a hauler
## fixating on one post type while another starves. Returns {} if nothing
## clears HAUL_MIN_THRESHOLD (or, for input jobs, if the stockpile has
## none of the needed resource to bring).
func _find_haul_job() -> Dictionary:
	var base := get_parent() as Base
	if not base:
		return {}

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
		var deficit: float = post.carry_limit - post.input_buffer
		if deficit > best_input_amount and GameState.resources.get(resource, 0.0) > 0.0:
			best_input = post
			best_input_amount = deficit
			best_input_resource = resource

	if best_output and (not best_input or best_output_amount >= best_input_amount):
		return {"post": best_output, "type": "output"}
	if best_input:
		return {"post": best_input, "type": "input", "resource": best_input_resource}
	return {}


## Walks from wherever the character currently is to the stockpile (Outpost
## Hall), drops everything in post.output_buffer into `drop_resource`, then
## - if `pickup_resource` is non-empty (Farm's own dedicated worker only; a
## generalist hauler delivers input via _deliver_to_post instead) -
## withdraws enough of it into post.input_buffer to top the buffer up to
## carry_limit, further capped by what the stockpile actually has. Leaves
## the character standing at the stockpile - it does NOT walk back to
## `post` afterward, since not every caller wants that (a lumberjack should
## head straight to the next tree, not detour back through the camp first;
## a farm worker needs to return to keep producing and handles that itself
## after calling this). Returns false if a reassignment (session change)
## interrupted the trip, telling the caller to stop rather than keep going.
func _haul_to_stockpile(post: Workstation, session: int, drop_resource: String, pickup_resource: String) -> bool:
	await get_tree().create_timer(_move_to(WorldGrid.stockpile_spot)).timeout
	if session != _work_session:
		return false

	if post.output_buffer > 0.0:
		GameState.add_resource(drop_resource, post.output_buffer)
		post.output_buffer = 0.0

	if not pickup_resource.is_empty():
		var take: float = minf(post.carry_limit - post.input_buffer, GameState.resources.get(pickup_resource, 0.0))
		if take > 0.0:
			GameState.spend({pickup_resource: take})
			post.input_buffer += take

	await get_tree().create_timer(STOCKPILE_PAUSE).timeout
	return session == _work_session


## The reverse of _haul_to_stockpile: walks to the stockpile first,
## withdraws up to post.carry_limit of `resource` (capped by post's
## remaining input space and what the stockpile actually has), then walks
## the resource out to `post` and deposits it into input_buffer. Used by
## idle haulers delivering input a workstation needs; a dedicated worker
## (e.g. Farm's own) still self-services its own pickup via
## _haul_to_stockpile's pickup_resource param instead (that one's a single
## atomic block with no travel gap, so it can't double-count the way this
## multi-leg trip could - see below). Returns false if a reassignment
## interrupted the trip.
func _deliver_to_post(post: Workstation, session: int, resource: String) -> bool:
	await get_tree().create_timer(_move_to(WorldGrid.stockpile_spot)).timeout
	if session != _work_session:
		return false

	var take: float = minf(post.carry_limit - post.input_buffer, GameState.resources.get(resource, 0.0))
	if take <= 0.0:
		return true
	GameState.spend({resource: take})

	await get_tree().create_timer(STOCKPILE_PAUSE).timeout
	if session != _work_session:
		# Carrying `take` and about to be reassigned - hand it back rather
		# than letting it vanish.
		GameState.add_resource(resource, take)
		return false

	await get_tree().create_timer(_move_to(post.get_worker_spot())).timeout
	if session != _work_session:
		GameState.add_resource(resource, take)
		return false

	# Re-check post.input_buffer now, not the stale reading from when `take`
	# was computed - another hauler (or the post's own dedicated worker) may
	# have topped it up while this trip was in transit. Only unload what
	# still fits; refund the rest to the stockpile instead of overshooting
	# carry_limit or destroying it. Without this, multiple idle haulers
	# converging on the same starved post all carry a full load computed
	# against the same "empty" snapshot and stack past carry_limit on
	# arrival.
	var space: float = maxf(0.0, post.carry_limit - post.input_buffer)
	var delivered: float = minf(take, space)
	post.input_buffer += delivered
	if delivered < take:
		GameState.add_resource(resource, take - delivered)
	return true


## The plain-labor case: no input to manage, no special walking pattern
## (LumberCamp) - just produce output_per_tick every work_interval and haul
## it out once carry_limit is hit. Used for any Workstation that isn't a
## Farm or LumberCamp (e.g. StoneMine). Runs until reassigned.
func _run_generic_work_loop(post: Workstation, session: int) -> void:
	while _work_active and session == _work_session:
		if post.output_buffer >= post.carry_limit:
			if not await _haul_to_stockpile(post, session, post.resource_type, ""):
				return
			continue

		await get_tree().create_timer(post.work_interval).timeout
		if session != _work_session:
			return

		var multiplier: float = data.get_skill_multiplier(post.get_skill_id())
		post.output_buffer += post.output_per_tick * multiplier
		gather_sound.play()
		_gain_skill_xp(post.get_skill_id(), XP_PER_GATHER)


## Converts input_resource into resource_type: consumes input_per_tick from
## input_buffer, produces output_per_tick into output_buffer, every
## work_interval. Hauls to the stockpile whenever the input buffer can't
## cover the next tick's cost, or the output buffer is full - whichever
## comes first, so a single trip handles both directions when possible.
## Despite the parameter name, `farm` covers every Farm-class building -
## raw crops and refinement buildings alike (see farm.gd). Runs until
## reassigned (session changes).
func _run_farm_loop(farm: Farm, session: int) -> void:
	while _work_active and session == _work_session:
		var multiplier: float = data.get_skill_multiplier(farm.get_skill_id())
		var input_needed: float = farm.input_per_tick * multiplier

		if farm.input_buffer < input_needed or farm.output_buffer >= farm.carry_limit:
			if not await _haul_to_stockpile(farm, session, farm.resource_type, farm.get_input_resource()):
				return
			await get_tree().create_timer(_move_to(farm.get_worker_spot())).timeout
			if session != _work_session:
				return
			if farm.input_buffer < input_needed:
				# Stockpile didn't have enough input to fully restock - wait
				# rather than immediately making another empty-handed trip.
				await get_tree().create_timer(IDLE_RETRY_DELAY).timeout
				if session != _work_session:
					return
				continue

		await get_tree().create_timer(farm.work_interval).timeout
		if session != _work_session:
			return

		# Re-check right before consuming, not just before the wait above -
		# with two workers sharing one Farm-class post (allowed, same as
		# LumberCamp), both can pass the earlier gate while input_buffer is
		# still sufficient and then both sit through their own work_interval
		# wait before touching it. Consuming unconditionally here would let
		# both decrement, driving input_buffer negative. Skipping this cycle
		# is safe: the loop just comes back around and hauls more in.
		if farm.input_buffer < input_needed:
			continue

		farm.input_buffer -= input_needed
		farm.output_buffer += farm.output_per_tick * multiplier
		gather_sound.play()
		_gain_skill_xp(farm.get_skill_id(), XP_PER_GATHER)


## Walk to a nearby tree and chop it (accumulating wood in the camp's
## output_buffer, not straight into the resource pool) until either the
## tree runs out or the buffer hits carry_limit, hauling a full buffer to
## the stockpile whenever it's ready. A tree that still has wood left when
## carry_limit is hit is released (not depleted) so it - or another
## worker - can pick it back up later. Before each chopping trip, tops up
## the local forest toward camp.optimal_tree_count if it's short - this is
## a shared area target, not a per-worker replant quota, so it plants
## whether or not this worker is the one who did the chopping. Runs until
## reassigned (session changes).
func _run_lumberjack_loop(camp: LumberCamp, session: int) -> void:
	while _work_active and session == _work_session:
		if camp.output_buffer >= camp.carry_limit:
			if not await _haul_to_stockpile(camp, session, "wood", ""):
				return
			continue

		var camp_cell: Vector2 = WorldGrid.local_to_grid(camp.get_worker_spot())

		if WorldGrid.count_trees_near(camp_cell, camp.search_radius) < camp.optimal_tree_count:
			var plant_cell = WorldGrid.find_plantable_cell(camp_cell, camp.search_radius)
			if plant_cell != null:
				var target := WorldGrid.grid_to_local(Vector2(plant_cell.x, plant_cell.y))
				await get_tree().create_timer(_move_to(target)).timeout
				if session != _work_session:
					return
				WorldGrid.plant_tree(plant_cell, false)
				_punch()
				continue

		var tree: WorldTree = WorldGrid.find_available_tree(camp_cell, camp.search_radius)

		if not tree:
			await get_tree().create_timer(IDLE_RETRY_DELAY).timeout
			continue

		tree.claimed = true
		_claimed_tree = tree
		await get_tree().create_timer(_move_to(tree.global_position)).timeout
		if session != _work_session:
			return

		while _work_active and session == _work_session and is_instance_valid(tree) and tree.wood_remaining > 0.0 and camp.output_buffer < camp.carry_limit:
			await get_tree().create_timer(camp.chop_interval).timeout
			if session != _work_session:
				return
			if not is_instance_valid(tree):
				break
			var gained: float = tree.harvest(camp.wood_per_chop)
			if gained > 0.0 and data:
				camp.output_buffer += gained * data.get_skill_multiplier(camp.get_skill_id())
				gather_sound.play()
				_gain_skill_xp(camp.get_skill_id(), XP_PER_GATHER)

		if is_instance_valid(tree) and tree.wood_remaining > 0.0:
			tree.claimed = false
		_claimed_tree = null
