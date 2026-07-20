We need a UI to at a glance see:
	- Number of Citizens
	- Name
	- Job
	- Happiness
	- Location
	- The ability to click on them to select them from the UI
		- Should snap the camera to that citizen

## Completion write-up (2026-07-17)

**Done:** new `CitizensPanel` (`scenes/ui/CitizensPanel.tscn`/`scripts/citizens_panel.gd`), opened via a new "Citizens" HUD button, same slide/fade panel convention every other option-picker panel already uses (modeled directly on `RecruitPanel`). Lists every citizen as a scrollable button (`ScrollContainer` around `ButtonContainer`, since the roster can exceed the ~9-option comfort zone the other panels stay within - deliberately no 1-9 keyboard shortcuts here for that same reason) showing:
- Number of citizens (panel title, "Citizens (3)")
- Name
- Job (`SkillTitles.get_title()` - the same title already shown above a selected citizen's head)
- Location (their assigned post's `display_name`, or "Hauling" if unassigned - `Character.assign_to(null)` always starts the hauler loop, so "Hauling" is accurate for every unassigned citizen, not just one caught mid-haul-trip)
- Happiness (`"72% (Content)"` - reuses `Base._happiness_band()`, the same banding the settlement-wide average already uses, just applied per-citizen)

Clicking a row calls `Base._on_citizen_selected_from_panel()`, which reuses `_on_character_selected()` verbatim (same in-world-click selection/skill-panel behavior) and additionally calls a new `RtsCamera.focus_on(position)` - an instant snap (not tweened - the ask says "snap," and every other camera move in `rts_camera.gd` - drag, edge-scroll - is already a direct position set, not tweened, so this matches rather than being the odd one out), clamped through the camera's existing `_clamp_position()` so snapping to a citizen near the map edge doesn't push the view past its configured limits.

Wired into the existing panel-mutual-exclusivity convention - every other panel-opening handler (`_on_build_pressed`, `_on_outpost_hall_clicked`, `_on_training_ground_clicked`, `_on_farm_clicked`, `_open_system_menu`) now also closes `citizens_panel`, and it closes on an outside click/Esc the same way `recruit_panel`/`crop_panel`/`training_ground_panel` already do.

**Verified:** instantiated the real `Base.tscn`, pressed the Citizens button (confirmed 3 rows for the 3 starting citizens), then pressed an actual row button (not calling Base's handler directly, to exercise the panel's real click->close wiring) and confirmed: the camera position became the exact target citizen's position, the panel closed (after its own tween), and the skill panel opened for that citizen - the same chain a real player click would trigger.
