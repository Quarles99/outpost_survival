- No tool tip appearing when mousing over skill or resource icons

## Completion write-up (2026-07-25)

**Root cause was two things, not one.** Tooltips did already work if you waited
long enough - `TooltipManager`'s custom hover delay was 2.0s while the native
`Control.tooltip_text` path (Build menu, crop panel) used the engine default
0.5s, a 4x mismatch that read as "broken" rather than "just slow." Separately,
a genuinely broken case was found while investigating: `hud.gd`'s
`_wire_tooltip()` never set `mouse_filter` on the Controls it wired, so the
five HUD stat labels (Water, Population, Idle Workers, Happiness, Day/Night) -
all `Label`s, which default to `MOUSE_FILTER_IGNORE` - could never receive
`mouse_entered` at all. Those five had never shown a tooltip, ever.

**What was built:**
- `autoload/tooltip_manager.gd`: `HOVER_DELAY` 2.0 -> 0.5.
- `project.godot`: added `gui/timers/tooltip_delay_sec=0.5` under a new
  `[gui]` section, so the native tooltip path is pinned to the same number
  instead of relying on an engine default that could silently change.
- `scripts/hud.gd`'s `_wire_tooltip()`: now sets
  `control.mouse_filter = Control.MOUSE_FILTER_STOP` before wiring
  `mouse_entered`/`mouse_exited`, fixing the five previously-dead stat
  tooltips.

**Key files:** `autoload/tooltip_manager.gd`, `project.godot`, `scripts/hud.gd`.

**Verification done:** headless `--quit` parse check only (clean, no errors).
Interactive in-game hover verification was **not** done this session - the
game window came up on the user's live desktop alongside other running
applications, and driving it via simulated mouse input risked interfering with
unrelated work on screen, so the user opted to verify manually instead. Please
confirm: Wood/Stone/Brick icons and Build-menu buttons show a tooltip after
~0.5s, and each of Water/Population/Idle Workers/Happiness/Day-Night now shows
one at all (previously never did).

**Known gaps:** none identified beyond the above pending manual confirmation.