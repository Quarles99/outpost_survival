extends RefCounted
class_name ResourceIcons

## Per-resource icon lookup for the icon-based resource UI requested in
## Outpost_Survival/Actionable Ideas/New Icons.md ("any references to
## resources in the UI should use the icon of that resource, not the
## name"). Crops directly from the two 16x16-cell sprite sheets the user
## dropped in - no new art asset needed, just AtlasTexture regions into
## them. grain/flour/hops have no exact-match icon in either sheet (no
## wheat sheaf, flour sack, or hop cone sprite exists in either pack) -
## those three are the closest visual stand-ins (a jar of grain, a pale
## sack, a leaf clump) and are the first place to look if better source
## art shows up later.
const FOOD_SHEET := preload("res://art/Food.png")
const ITEMS_SHEET := preload("res://art/items_sheet.png")
const CELL := 16

## resource_name -> [sheet, column, row] (column/row are 0-indexed 16x16 cells)
const ICON_CELLS := {
	"wood": [ITEMS_SHEET, 19, 27],
	"stone": [ITEMS_SHEET, 21, 25],
	"brick": [ITEMS_SHEET, 22, 17],
	"grain": [FOOD_SHEET, 4, 7],
	"flour": [ITEMS_SHEET, 0, 10],
	"hops": [ITEMS_SHEET, 21, 27],
	"bread": [FOOD_SHEET, 1, 6],
	"beer": [FOOD_SHEET, 4, 2],
	"fruit": [FOOD_SHEET, 4, 1],
	"potato": [FOOD_SHEET, 7, 1],
	"cabbage": [ITEMS_SHEET, 8, 10],
}


static func get_icon(resource_name: String) -> AtlasTexture:
	if not ICON_CELLS.has(resource_name):
		return null
	var entry: Array = ICON_CELLS[resource_name]
	var atlas := AtlasTexture.new()
	atlas.atlas = entry[0]
	atlas.region = Rect2(entry[1] * CELL, entry[2] * CELL, CELL, CELL)
	return atlas
