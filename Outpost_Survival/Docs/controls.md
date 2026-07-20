# Controls

## Main Menu

| Input | Action |
|---|---|
| **Continue** | Load whichever of the 3 save slots was saved most recently |
| **New Game** | Choose a slot to start a fresh game in |
| **Load Game** | Choose a slot to load |
| **Quit** | Exit the game |
| `1`–`3` (with the slot picker open) | Choose the corresponding slot |
| Esc (with the slot picker open) | Cancel and return to the main menu |

## Camera

| Input | Action |
|---|---|
| Scroll wheel | Zoom in / out |
| Middle-mouse hold + drag | Pan camera |
| Move cursor to screen edge | Pan camera continuously ("edge scroll") |

## X-ray Reveal

| Input | Action |
|---|---|
| Hold `Shift` | Fades trees/buildings in a circular zone around the cursor so a citizen hidden behind one becomes visible — purely visual, has no effect on the game world |
| Left-click while holding `Shift` | If a citizen is under the cursor, selects them even if a tree/building visually on top of them would otherwise take the click |

## Fast Forward

| Input | Action |
|---|---|
| Click the **Speed** button (HUD) | Cycle 1x → 2x → 4x → back to 1x |
| `+`/`-` | Same cycle, one step at a time |

## Citizens

Job assignment is fully automatic — there's no way to manually assign a citizen anymore (see [mechanics.md](mechanics.md#assigning-citizens)). Clicking a citizen is purely informational.

| Input | Action |
|---|---|
| Left-click a citizen | Select them, opening their (view-only) skill panel |
| Left-click the *same*, already-selected citizen again | Deselect them (same as clicking elsewhere) |
| Left-click empty ground, or Esc | Deselect the current citizen / close their skill panel |
| Click the **Citizens** button (HUD) | Open a scrollable list of every citizen - name, job title, current location (post name or "Hauling"), and happiness |
| Click a citizen's row in that list | Same as clicking them in-world (selects them, opens their skill panel) - additionally snaps the camera straight to them |
| Left-click empty ground, or Esc (with the Citizens list open) | Close it |

## Disabling a post

| Input | Action |
|---|---|
| Right-click an already-placed job post (Farm-family, Lumber Camp, Stone Mine) | Toggle it disabled/re-enabled — disabling immediately evicts its current worker (back to hauling) and blocks automatic assignment from staffing it until re-enabled |

## Recruitment

| Input | Action |
|---|---|
| Left-click the Outpost Hall | Open the recruitment panel (3 candidates) |
| Left-click a built Barracks/Archery Range/Mage Tower | Open a panel with a short description, then Recruit (a single candidate in that building's own combat skill, on its own independent once-per-day cooldown), Upgrade (spend brick to raise that building's unit cap by 3), and - for a Barracks/Archery Range - one "Train: \<Unit\>" option per unit type that building can produce |
| `1`–`3` (with recruitment panel open) | Recruit the corresponding candidate |
| Numbered (with a training building's panel open) | Choose the corresponding option - Recruit/Upgrade/whichever unit type, free and instant to change your mind later |
| Left-click empty ground, or Esc | Close whichever panel is open |

## Building

| Input | Action |
|---|---|
| Click the **Build** button (HUD) | Open the build menu |
| Hover a building button (with build menu open) | Show its full name and cost (the button itself only shows a short name) |
| `1`–`9` (with build menu open) | Choose the corresponding building |
| Move mouse (while placing) | Move the placement ghost, snapped to the grid — green means the spot is valid, red means it isn't (out of bounds, occupied, or unaffordable) |
| Left-click (while placing, on a valid spot) | Confirm placement |
| Right-click, or Esc (while placing) | Cancel placement |

## Retooling a Farm

| Input | Action |
|---|---|
| Left-click an already-placed Farm-family building | Open a panel with a short description of the current crop, then a grid to retool it into any other Farm-family recipe, free and instant |
| Right-click an already-placed Farm-family building | Toggle it disabled/re-enabled (see Disabling a post above) — doesn't open the retool panel |
| `1`–`9` (with the retool panel open) | Choose the corresponding recipe |
| Left-click empty ground, or Esc | Close the retool panel |

## Building info

| Input | Action |
|---|---|
| Left-click an already-placed Lumber Camp/Stone Mine/Brickmaker/Mill/Bakery/Brewery/Construction Site | Open a panel with a short description, its recipe (input → output per cycle, or wood per chop for a Lumber Camp), and who's currently employed there |
| Left-click an already-placed House | Open a panel with a short description and, if not already upgraded, an Upgrade button previewing its cost (100 wood + 50 brick) before anything is spent |
| Left-click empty ground, or Esc | Close whichever panel is open |

## Battle Deployment

| Input | Action |
|---|---|
| Click the **Simulate Attack** button (HUD) | Deploy every citizen currently assigned to a Barracks/Archery Range/Mage Tower as a squad against a generated enemy raiding party (see [mechanics.md](mechanics.md#battle-deployment)) — no-op with a flashed warning if no citizen is currently stationed at one |
| `R` (in the battle scene) | Restart the current fight with the same deployed squad against a freshly generated enemy |
| `+`/`-` (in the battle scene) | Battle speed (0.5x–16x) |
| Esc (in the battle scene) | Return to the settlement, applying the battle's outcome |

## System Menu (in-game)

| Input | Action |
|---|---|
| Esc, when nothing else is selected/open | Open the System Menu |
| Click the **Menu** button (HUD) | Open the System Menu |
| **Resume** | Close the menu |
| **Save Game** / **Load Game** | Open the slot picker (see Main Menu above) to save into, or load from, any of the 3 slots |
| **Main Menu** | Return to the main menu (progress since the last save is lost unless saved first) |
| **Quit to Desktop** | Exit the game |

## Save / Load

| Input | Action |
|---|---|
| `F5` | Quicksave to the active slot (whichever was last saved/loaded, via the main menu or System Menu) |
| `F9` | Quickload from the active slot |

Both keys act on the active slot, with a brief on-screen "Saved"/"Loaded" flash as feedback — use the System Menu's Save/Load buttons instead to pick a different slot.
