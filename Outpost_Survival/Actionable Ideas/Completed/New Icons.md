I have added two new sprite sheets into the art folder: ![[Food.png]]

![[items_sheet.png]]

These icons can be used across the game, any references to resources in the UI should use the icon of that resource, not the name.

## Completion write-up (2026-07-18)

Built `scripts/resource_icons.gd` (`ResourceIcons`, `extends RefCounted`, matching `BuildingCatalog`'s static-catalog convention) - a single `resource_name -> [sheet, column, row]` dict (`ICON_CELLS`) covering all 11 `GameState` resources, cropping directly from `art/Food.png`/`art/items_sheet.png` (both on a clean 16x16px grid) via `AtlasTexture` regions - no new art asset baked, no runtime texture generation beyond the `AtlasTexture` itself.

**Mapping** (picked by visual inventory of both sheets - see the sheets themselves for anything better if reconsidered later):
- `wood` → items_sheet (19,27) log, `stone` → items_sheet (21,25) slab, `brick` → items_sheet (22,17) red bar, `cabbage` → items_sheet (8,10) leafy head
- `bread` → Food.png (1,6) loaf, `beer` → Food.png (4,2) stein, `fruit` → Food.png (4,1) apple, `potato` → Food.png (7,1)
- `grain`/`flour`/`hops` have **no exact-match icon in either sheet** (no wheat sheaf, flour sack, or hop cone exists in either pack) - used the closest stand-ins instead: `grain` → Food.png (4,7) jar of grain-colored kernels, `flour` → items_sheet (0,10) pale sack, `hops` → items_sheet (21,27) green leaf clump. First place to look if better source art shows up.

**Wired into:**
- `scripts/hud.gd`/`scenes/ui/HUD.tscn` - Wood/Stone rows became `HBoxContainer`s (`WoodRow`/`StoneRow`) with an icon `TextureRect` + the existing amount/rate `Label` (text dropped the `"Wood: "`/`"Stone: "` prefix, icon replaces it). The Food breakdown's 7 sub-rows (built dynamically in `_ready()`) got the same icon+label treatment, with a small indent spacer standing in for the old `"    "` text indent; each icon carries `tooltip_text` (the old display name) for hover discoverability now that the name isn't printed.
- `scripts/build_menu.gd` - `_add_button` gained `_add_cost_row()`, a small icon+number chip row along each building button's bottom edge (12x12→10x10 icons after a first pass overflowed 2-digit costs past the 64px button and got clipped - see `_add_cost_row`'s sizing). The tooltip still includes the old `_format_cost()` text as an accessibility fallback; the chips are the primary visible readout now.

**Verification:** headless editor pass confirmed `ResourceIcons` registers as a global class with no parse errors. Real-instantiation screenshot pass (throwaway `scenes/_verify_icons.tscn` instancing `Base.tscn`, emitting `hud.build_pressed`/calling `_on_food_button_pressed()`, `get_viewport().get_texture().get_image().save_png()`, then deleted) confirmed: HUD Wood/Stone rows render crisp icons at 20x20, the Food breakdown's 7 icons are all visually distinct at 18x18, and every Build menu button's cost chips fit inside the 64px square without clipping (caught the first-pass 12px/6px-separation version clipping Storage's `25`/`25` cost, fixed by shrinking to 10px icons/1px-3px separation).

**Known gaps:** `grain`/`flour`/`hops` icons are approximations, not exact matches - flagged above. No other UI surface (build ghost ants, character skill panel, etc.) references resources by name currently, so HUD + Build menu covers every existing text-based resource reference in the game as of this pass.