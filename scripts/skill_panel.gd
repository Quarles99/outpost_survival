extends CanvasLayer
class_name SkillPanel

const SLIDE_OFFSET := Vector2(0, 20)
const ANIM_DURATION := 0.18

## Every skill a citizen can train: the 8 work skills a Workstation/Farm-
## family/Brickmaker/ConstructionSite post can train, the 3 combat skills a
## TrainingGround post can train (melee_combat/archery/spellcasting - see
## training_ground.gd), plus "speed"/"strength" - the 2 universal skills
## every citizen trains passively regardless of assignment (see
## Character.SPEED_XP_PER_SECOND's doc comment). RecruitCatalog.
## SPECIALIZATIONS has its own copy of the work-skill labels for a
## different purpose (picking a recruit's starting specialization, not
## listing everything a citizen has) - small, stable, and separate enough a
## shared constant felt like unneeded coupling between the two panels.
const SKILL_DISPLAY_ORDER := ["farming", "lumberjacking", "mining", "masonry", "milling", "baking", "brewing", "construction", "melee_combat", "archery", "spellcasting", "speed", "strength"]
const SKILL_LABELS := {
	"farming": "Farming",
	"lumberjacking": "Lumberjacking",
	"mining": "Mining",
	"masonry": "Masonry",
	"milling": "Milling",
	"baking": "Baking",
	"brewing": "Brewing",
	"construction": "Construction",
	"melee_combat": "Melee Combat",
	"archery": "Archery",
	"spellcasting": "Spellcasting",
	"speed": "Speed",
	"strength": "Strength",
}

const ICON_SIZE := 20

@onready var panel_control: Control = $Control
@onready var name_label: Label = $Control/Margin/VBoxContainer/NameLabel
@onready var task_label: Label = $Control/Margin/VBoxContainer/TaskLabel
@onready var skill_list: GridContainer = $Control/Margin/VBoxContainer/SkillList

var _base_position: Vector2
var _anim_tween: Tween
## One entry per currently-shown skill row (icon+level HBoxContainer) -
## freed and rebuilt whole on every open_for() call, same as the old flat
## Label list this replaced.
var _skill_rows: Array[Control] = []


func _ready() -> void:
	visible = false
	_base_position = panel_control.position


## Always shows all 13 skills in SKILL_DISPLAY_ORDER, including untrained
## ones at level 1 - a fixed layout that doesn't reflow as a citizen picks
## up new skills reads more like a stats sheet than a shrinking/growing list.
## Each skill is an icon (SkillIcons - hover for name/description via
## TooltipManager, see Fix character stats sheet overflowing menu.md) plus
## a bare "Lv N" label, laid out 2-per-row in SkillList's GridContainer -
## replaces the old single column of "Skill Name: Lv N" text labels, which
## is what was overflowing the panel (13 full-width rows plus name/task/
## esc). task_label is a point-in-time snapshot of Character.current_task
## (see its own doc comment) - re-open (re-click the citizen) for a fresh
## read rather than watching it live-update.
func open_for(character: Character) -> void:
	name_label.text = character.data.character_name if character.data else "Unknown"
	task_label.text = character.current_task
	_clear_skill_labels()

	for skill_id in SKILL_DISPLAY_ORDER:
		var level := character.data.get_skill_level(skill_id) if character.data else 1
		var row := HBoxContainer.new()

		var icon := TextureRect.new()
		icon.texture = SkillIcons.get_icon(skill_id)
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		var title: String = SKILL_LABELS[skill_id]
		var body := SkillIcons.get_description(skill_id)
		icon.mouse_entered.connect(func() -> void: TooltipManager.request(title, body))
		icon.mouse_exited.connect(func() -> void: TooltipManager.cancel())
		row.add_child(icon)

		var label := Label.new()
		label.text = "Lv %d" % level
		row.add_child(label)

		skill_list.add_child(row)
		_skill_rows.append(row)

	visible = true
	panel_control.position = _base_position + SLIDE_OFFSET
	panel_control.modulate.a = 0.0

	if _anim_tween:
		_anim_tween.kill()
	_anim_tween = create_tween().set_parallel()
	_anim_tween.tween_property(panel_control, "position", _base_position, ANIM_DURATION).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(panel_control, "modulate:a", 1.0, ANIM_DURATION)


func close() -> void:
	if not visible:
		return
	if _anim_tween:
		_anim_tween.kill()
	_anim_tween = create_tween().set_parallel()
	_anim_tween.tween_property(panel_control, "position", _base_position + SLIDE_OFFSET, ANIM_DURATION).set_ease(Tween.EASE_IN)
	_anim_tween.tween_property(panel_control, "modulate:a", 0.0, ANIM_DURATION)
	_anim_tween.chain().tween_callback(func() -> void: visible = false)


func _clear_skill_labels() -> void:
	for row in _skill_rows:
		row.queue_free()
	_skill_rows.clear()
