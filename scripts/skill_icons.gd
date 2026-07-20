extends RefCounted
class_name SkillIcons

## Per-skill icon lookup for SkillPanel's stats sheet (Fix character stats
## sheet overflowing menu.md - "replace skill names with icons that can be
## hovered over for more information"). Five job skills already map 1:1 to
## a single resource (see SkillTitles.TITLE_SKILLS/Workstation subclasses) -
## those reuse that resource's own ResourceIcons entry rather than hunting
## for a second icon of the same thing (masonry, the Brickmaker's stone->
## brick skill, shows the stone icon; farming/milling/baking/brewing show
## their crop/product icon). The remaining 8 skills (the 3 raw-gather
## trades, the 3 combat skills, and the 2 universal speed/strength skills)
## get a dedicated tool icon instead, cropped from the same items_sheet.png
## ResourceIcons already crops from - picked by visual inventory of that
## sheet (see the "Fix character stats sheet overflowing menu" completion
## write-up for exactly which rows/columns were considered and ruled out).
const ITEMS_SHEET := preload("res://art/items_sheet.png")
const CELL := 16

## skill_id -> [column, row] (0-indexed 16x16 cells in ITEMS_SHEET).
const SKILL_ICON_CELLS := {
	"melee_combat": [0, 0],
	"mining": [2, 1],
	"lumberjacking": [6, 1],
	"construction": [4, 1],
	"spellcasting": [3, 2],
	"archery": [8, 5],
	"strength": [2, 8],
	"speed": [6, 8],
}

## skill_id -> resource_name, for the 5 skills that reuse ResourceIcons
## instead of getting their own SKILL_ICON_CELLS entry.
const RESOURCE_BACKED_SKILLS := {
	"farming": "cabbage",
	"masonry": "stone",
	"milling": "flour",
	"baking": "bread",
	"brewing": "beer",
}


static func get_icon(skill_id: String) -> AtlasTexture:
	if RESOURCE_BACKED_SKILLS.has(skill_id):
		return ResourceIcons.get_icon(RESOURCE_BACKED_SKILLS[skill_id])
	if not SKILL_ICON_CELLS.has(skill_id):
		return null
	var cell: Array = SKILL_ICON_CELLS[skill_id]
	var atlas := AtlasTexture.new()
	atlas.atlas = ITEMS_SHEET
	atlas.region = Rect2(cell[0] * CELL, cell[1] * CELL, CELL, CELL)
	return atlas


## One-line blurb per skill for SkillPanel's per-icon tooltip (hover, via
## TooltipManager) - same spirit/pattern as ResourceIcons.RESOURCE_
## DESCRIPTIONS. The 5 resource-backed skills intentionally don't repeat
## ResourceIcons.get_description() verbatim - phrased in terms of the
## skill/action rather than the resource, since that's what's actually
## being hovered here.
const SKILL_DESCRIPTIONS := {
	"farming": "Grows crops at a Farm-family building. Higher level raises output per cycle.",
	"lumberjacking": "Chops trees for wood at a Lumber Camp. Higher level raises output per chop.",
	"mining": "Mines stone at a Stone Mine. Higher level raises output per cycle.",
	"masonry": "Bakes stone into brick at a Brickmaker. Higher level raises output per cycle.",
	"milling": "Mills grain into flour. Higher level raises output per cycle.",
	"baking": "Bakes flour into bread. Higher level raises output per cycle.",
	"brewing": "Brews hops into beer. Higher level raises output per cycle.",
	"construction": "Builds construction sites into finished buildings. Higher level adds labor per work tick.",
	"melee_combat": "Melee damage in combat. Trained at a Barracks.",
	"archery": "Ranged damage in combat. Trained at an Archery Range.",
	"spellcasting": "Spell damage in combat. Trained at a Mage Tower.",
	"speed": "Move speed. Trained passively while walking, regardless of job.",
	"strength": "Haul carry size. Trained passively while hauling, regardless of job.",
}


static func get_description(skill_id: String) -> String:
	return SKILL_DESCRIPTIONS.get(skill_id, "")
