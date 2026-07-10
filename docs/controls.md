# Controls

## Camera

| Input | Action |
|---|---|
| Scroll wheel | Zoom in / out |
| Middle-mouse hold + drag | Pan camera |
| Move cursor to screen edge | Pan camera continuously ("edge scroll") |

## Citizens

There's no task menu — assignment is drag-and-drop, or select-then-click.

| Input | Action |
|---|---|
| Left-click a citizen | Select them, opening their skill panel |
| Left-click a workstation/wall while a citizen is selected | Assign them to that post (denied with a HUD message if it's already at its worker cap) |
| Left-click the *same*, already-selected citizen again | Unassign them (set them idle) |
| Left-click-drag a citizen onto a workstation/wall | Assign them to that post directly, without selecting first |
| Release a drag off any valid post | Cancels the drag — the citizen returns to their current spot without interrupting their work |
| Right-click, or Esc, mid-drag | Cancel the drag |
| Left-click empty ground, or Esc | Deselect the current citizen / close their skill panel |

## Recruitment

| Input | Action |
|---|---|
| Left-click the Outpost Hall | Open the recruitment panel (3 candidates) |
| `1`–`3` (with recruitment panel open) | Recruit the corresponding candidate |
| Left-click empty ground, or Esc | Close the recruitment panel |

## Building

| Input | Action |
|---|---|
| Click the **Build** button (HUD) | Open the build menu |
| Hover a building icon (with build menu open) | Show its full name and cost (icons are condensed and don't fit that text directly) |
| `1`–`9` (with build menu open) | Choose the corresponding building |
| Move mouse (while placing) | Move the placement ghost, snapped to the grid — green means the spot is valid, red means it isn't (out of bounds, occupied, or unaffordable) |
| Left-click (while placing, on a valid spot) | Confirm placement |
| Right-click, or Esc (while placing) | Cancel placement |

## Retooling a Farm

| Input | Action |
|---|---|
| Left-click an already-placed Farm-family building, with no citizen selected | Open a panel to retool it into any other Farm-family recipe, free and instant |
| Left-click an already-placed Farm-family building, with a citizen selected | Assign that citizen there instead (see Citizens above) — takes priority over retooling |
| `1`–`9` (with the retool panel open) | Choose the corresponding recipe |
| Left-click empty ground, or Esc | Close the retool panel |

## Save / Load

| Input | Action |
|---|---|
| `F5` | Quicksave (writes to the single local save file) |
| `F9` | Quickload (reloads from the single local save file) |

There is no save/load menu yet — both keys act on one fixed local save slot, with a brief on-screen "Saved"/"Loaded" flash as the only feedback.
