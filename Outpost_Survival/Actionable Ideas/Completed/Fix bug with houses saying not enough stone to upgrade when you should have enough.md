## Completion write-up (2026-07-20)

Already fixed as a side effect of the "Building click UI" item (see `Actionable Ideas/Completed/Building click UI.md`) - same session, found independently while tracing House's upgrade flow before this note appeared.

**Root cause:** `House.UPGRADE_COST` is `{"brick": 50.0, "wood": 100.0}` - no stone at all - but `Base._on_house_clicked`'s old failure path hardcoded `hud.flash_message("Not enough stone")` regardless of what was actually missing. That string had gone stale at some earlier balance pass (stone was dropped from the upgrade cost entirely - see `house.gd`'s own doc comment: "an upgraded ('stone') house should be built from worked brick, not the raw ore itself") without the message being updated to match, so a player with plenty of stone but insufficient brick/wood saw a message actively pointing at the wrong resource.

**Fix:** House's click no longer spends blind and reports failure after the fact at all - it now opens a panel previewing the real cost ("Upgrade (50 Brick + 100 Wood)\n+2 capacity") before anything is spent, and the one remaining failure message (`Base._confirm_house_upgrade`) is built from `House.UPGRADE_COST` itself via `_format_cost()` rather than a hardcoded string, so it can't drift out of sync with the actual cost again.

**Verification:** Same as Building click UI's own write-up - confirmed via code trace and a clean full-project headless load, not a live click-through (user had their own Godot session open playtesting at the time).
