extends Label
class_name GatherFeedback

## Spawns minimal floating-then-fading text announcing a single production
## tick's yield and skill xp gain (e.g. "+1.2 Food  +4 xp"), rising and
## fading over FLOAT_DURATION then freeing itself. Deliberately terse (one
## line, small font, brief) per Implement_Next.txt's "very minimal so as
## not to clutter the screen" requirement - this fires on every gather tick
## for every working citizen, so anything heavier would spam the screen.
const FLOAT_DISTANCE := 28.0
const FLOAT_DURATION := 1.0
const SPAWN_OFFSET := Vector2(-24, -40)


## `parent` should be the spawning character's own parent (Base, per the
## y-sort convention - see CLAUDE.md) so `local_position` (already in that
## same local coordinate space) lines up without a global/local conversion.
## z_index deliberately mirrors the IsoGround/"always render regardless of
## y-sort" trick documented in CLAUDE.md, rather than fighting the y-sort
## key for a transient overlay that must always read on top.
static func spawn(parent: Node, local_position: Vector2, resource_type: String, amount: float, xp: float) -> void:
	var label := GatherFeedback.new()
	label.text = "+%.1f %s  +%d xp" % [amount, resource_type.capitalize(), xp]
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.z_index = 100
	label.position = local_position + SPAWN_OFFSET
	parent.add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - FLOAT_DISTANCE, FLOAT_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_DURATION)
	tween.chain().tween_callback(label.queue_free)
