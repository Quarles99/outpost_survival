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

@onready var panel_control: Control = $Control
@onready var name_label: Label = $Control/Panel/VBoxContainer/NameLabel
@onready var skill_list: VBoxContainer = $Control/Panel/VBoxContainer/SkillList

var _base_position: Vector2
var _anim_tween: Tween
var _skill_labels: Array[Label] = []


func _ready() -> void:
	visible = false
	_base_position = panel_control.position


## Always shows all 13 skills in SKILL_DISPLAY_ORDER, including untrained
## ones at level 1 - a fixed layout that doesn't reflow as a citizen picks
## up new skills reads more like a stats sheet than a shrinking/growing list.
func open_for(character: Character) -> void:
	name_label.text = character.data.character_name if character.data else "Unknown"
	_clear_skill_labels()

	for skill_id in SKILL_DISPLAY_ORDER:
		var level := character.data.get_skill_level(skill_id) if character.data else 1
		var label := Label.new()
		label.text = "%s: Lv %d" % [SKILL_LABELS[skill_id], level]
		skill_list.add_child(label)
		_skill_labels.append(label)

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
	for label in _skill_labels:
		label.queue_free()
	_skill_labels.clear()
