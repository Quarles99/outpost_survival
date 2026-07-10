# Stats Reference

Every concrete number currently in the game. Grouped by system; see [mechanics.md](mechanics.md) for how these numbers are used.

## Starting State

| | Value |
|---|---|
| Starting food | 10 |
| Starting wood | 10 |
| Starting stone / grain / flour / bread / hops / beer / fruit / potato | 0 each |
| Starting population | 3 (Aldric, Brenna, Cass) |
| Starting population capacity | 3 |
| Starting water access | None (no Well built) |
| Starting citizen skill levels | All skills level 1 (0 xp) |
| Initial scattered trees | 12, mature, scattered within 5 tiles of the starting Lumber Camp |

## Resource Storage

| | Value |
|---|---|
| Baseline storage capacity (per resource, with no Storage Facility) | 30 |
| Storage Facility bonus | +30 (stacks per facility built) |
| Overflow behavior | Excess above capacity is lost, not refunded |
| Food-equivalent resources (drawn down for hunger, in priority order) | food → bread → potato → fruit |

## Resource Consumption

| | Value |
|---|---|
| Food (or food-equivalent) eaten per citizen | 0.3 / second |
| Consumption tick interval | every 1 second |
| Applies to | every citizen, regardless of work assignment |
| Floor | resources can't go below 0 |

## Buildings

| Building | Footprint | Cost | Grants | Notes |
|---|---|---|---|---|
| Outpost Hall | 2×2 | 20 wood | — | A stockpile drop-off/pickup point - haulers use whichever registered stockpile (any Outpost Hall or Storage Facility) is nearest. |
| Cabbage Farm | 2×2 | 6 wood | — | Converts wood → food. See production table below. |
| Lumber Camp | 1×1 | 5 wood | — | Produces wood by chopping trees. See production table below. |
| House | 2×2 | 10 wood | +2 population capacity | Passive — no worker slot. |
| Stone Mine | 1×1 | 8 wood | — | Produces stone, no input needed. See production table below. |
| Well | 1×1 | 10 stone + 4 wood | +1 to water-well count (unlocks water access) | Passive — no worker slot. |
| Storage Facility | 2×4 | 15 wood + 10 stone | +30 storage capacity (all resources) | Also a stockpile drop-off/pickup point, same as the Outpost Hall, and assignable as a hauler post (see Assigning Citizens). Not upgradeable in place yet; build another for more capacity. |
| Grain Farm | 2×2 | 6 wood | — | Converts wood → grain. Crop-chain building; see table below. |
| Mill | 2×2 | 8 wood | — | Converts grain → flour. |
| Bakery | 2×2 | 8 wood + 4 stone | — | Converts flour → bread (edible). |
| Hops Farm | 2×2 | 6 wood | — | Converts wood → hops. |
| Brewery | 2×2 | 10 wood + 4 stone | — | Converts hops → beer (luxury good, not edible). |
| Fruit Orchard | 2×2 | 8 wood | — | Produces fruit (edible), no input needed — slower but reliable. |
| Potato Farm | 2×2 | 6 wood | — | Produces potato (edible), no input needed. |

All 8 of the above (Farm through Potato Farm) can be clicked once placed to retool into any other one of the 8, for free, at any time - see [mechanics.md](mechanics.md#building--placement).

## Workstation Production

| | Farm | Lumber Camp | Stone Mine |
|---|---|---|---|
| Output resource | food | wood | stone |
| Output per work cycle | 1.0 × skill multiplier | 2.0 × skill multiplier (per chop) | 0.5 × skill multiplier |
| Input resource | wood | — | — |
| Input cost per work cycle | 0.5 wood flat (not scaled by skill) | — | — |
| Work cycle interval | 1.5 s | 1.2 s (per chop) | 1.5 s |
| Carry limit (output buffer cap / haul size) | 6.0 | 6.0 | 6.0 |
| Search radius (tree-finding, Lumber Camp only) | — | 4.5 tiles | — |
| Target forest size maintained (Lumber Camp only) | — | 16 trees within search radius | — |
| Skill trained | `farming` | `lumberjacking` | `mining` |
| Max workers assigned at once | 3 | 3 | 3 |

## Worker Caps (`Workstation`, `WallSegment`, `OutpostHall`, `StorageFacility`)

| | Value |
|---|---|
| Max workers per Workstation (Farm-family, Lumber Camp, Stone Mine) | 3 |
| Max workers per Wall Segment | 1 |
| Max haulers per Outpost Hall or Storage Facility | 10 (generous rather than matching Workstation's 3 - haulers don't share a production buffer, so there's no throughput reason to bottleneck it) |

The **Farm** class is a generic single-input/single-output converter (exported `input_per_tick`, `input_resource`, `skill_id`, `sprite_tint`) — the row above is its default configuration (wood → food, "farming"). The full Alternative Crop Types chain is built from the same class, sharing one scene (`CropStation.tscn`) and distinguished only by catalog configuration:

| Building | Input → Output | Input/tick | Output/tick | Work interval | Skill trained |
|---|---|---|---|---|---|
| Grain Farm | wood → grain | 0.5 | 1.0 | 1.5 s (default) | `farming` |
| Mill | grain → flour | 1.0 | 1.0 | 1.5 s (default) | `milling` |
| Bakery | flour → bread | 1.0 | 1.0 | 1.5 s (default) | `baking` |
| Hops Farm | wood → hops | 0.5 | 1.0 | 1.5 s (default) | `farming` |
| Brewery | hops → beer | 1.0 | 1.0 | 1.5 s (default) | `brewing` |
| Fruit Orchard | none → fruit | 0 | 0.6 | 3.0 s (slower) | `farming` |
| Potato Farm | none → potato | 0 | 1.0 | 1.5 s (default) | `farming` |

Output/tick scales by the worker's skill multiplier the same way the base Farm's does; input/tick does not - a higher-level worker gets more output from the same input, not just more of both at a fixed ratio. Fruit Orchard and Potato Farm never haul input (no delivery trip is ever triggered) — matching the design intent of a "consistent" crop that isn't gated on deliveries.

A Farm-class post's haul trip triggers when its input buffer can't cover the next work cycle's input cost, or its output buffer is full (whichever comes first). A Lumber Camp or Stone Mine's haul trip triggers when its output buffer hits the carry limit.

## Trees (`WorldTree`)

| | Value |
|---|---|
| Wood per mature tree | 20.0 |
| Sapling → maturity grow time | 25 seconds |
| Sapling starting visual scale | 0.35× of full size |
| Wood harvested per chop | 2.0 × chopper's skill multiplier |

## Skill Curve (`SkillCurve`)

RuneScape-style exponential 1–99 curve: `xp_for_level(L) = floor(1/4 * sum[n=1..L-1] floor(n + 300 * 2^(n/7)))`.

| | Value |
|---|---|
| Max level | 99 |
| Output multiplier per level above 1 | +2% |
| Multiplier at level 99 | ~2.96× a level-1 worker |
| XP granted per gather action (chop or production tick) | 4.0 flat, regardless of level or output |

## Movement & Work Timing (`Character`)

| | Value |
|---|---|
| Move speed | 140 px/s (before the speed skill's multiplier) |
| Min move duration (even for very short trips) | 0.3 s |
| Max move duration (even for very long trips) | 4.0 s |
| Pause at stockpile per haul trip | 0.3 s |
| Idle retry delay (no work found / target too empty) | 2.5 s |
| Minimum buffer amount worth an idle-hauler trip | 1.0 |

## Water Farming Bonus (`Character`)

| | Value |
|---|---|
| Farm-family output bonus with a Well built | 1.25× (output only, input cost unaffected) |

## Speed & Strength (`Character`)

| | Value |
|---|---|
| Speed xp per second spent moving | 2.5 |
| Strength xp per haul trip that moved anything | 4.0 (same flat amount as XP_PER_GATHER) |
| Effect of speed | Multiplies move speed (140 px/s base), same +2%/level curve as any other skill |
| Effect of strength | Multiplies a workstation's base carry_limit for that character's own haul trips |
| Trained by | Existing/moving (speed) and completing a haul trip (strength) - regardless of work assignment, unlike every other skill |

## Camera (`RtsCamera`)

| | Value |
|---|---|
| Zoom range | 0.5× (zoomed out) – 2.0× (zoomed in) |
| Zoom step per scroll click | 0.1 |
| Zoom tween duration | 0.15 s |
| Edge-scroll trigger margin | 24 px from screen edge |
| Edge-scroll speed | 900 px/s (world space, scaled by zoom) |
| Extra pan room beyond map bounds | 320 world units |

## Income Rate (`GameState`)

| | Value |
|---|---|
| History sample interval | 1 s |
| Rolling window | Exactly 60 s once that much history exists (interpolated between samples straddling the boundary); shorter and exact just after boot |
| Displayed for | Food, Wood, Stone (the HUD's dedicated resource rows) |

## Happiness (`Base`, `CharacterData`)

| | Value |
|---|---|
| Happiness range | 0–100 |
| Starting happiness | 50 |
| Happiness re-target tick interval | 5 s |
| Ease rate (max change per tick) | 3.0 toward target |
| Baseline target (before bonuses/penalties) | 50 |
| Water access bonus/penalty | ±15 |
| Food-in-stock bonus | +15 |
| Starving (no food at all) penalty | −20 |
| Bonus per distinct food-equivalent resource in stock | +5 (see food-equivalent list above) |
| Unhappy threshold | below 20 |
| Consecutive unhappy ticks before a citizen leaves | 12 (12 × 5 s = 60 s) |

### Happiness Bands (production multiplier)

| Band | Settlement happiness | Output multiplier |
|---|---|---|
| Thriving | ≥ 80 | 1.15× |
| Content | ≥ 50 | 1.0× |
| Unhappy | ≥ 20 | 0.85× |
| Miserable | < 20 | 0.6× |

## Citizen Recruitment (`RecruitCatalog`)

| | Value |
|---|---|
| Candidates offered per visit | 3 |
| Recruit cost | 15 food |
| Starting specialization level | 5 |
| Possible specializations | farming, lumberjacking, mining, milling, baking, brewing |
| Gated on | open population capacity, and affording the food cost |

## Map Size (`IsoGround`, `Base.tscn`)

| | Value |
|---|---|
| Playable grid | 28×28 tiles (784 total) |
| Grid coordinate range | x: -12..15, y: -12..15 |

## Display (`project.godot`)

| | Value |
|---|---|
| Base viewport size | 1280×720 |
| Stretch mode | `canvas_items` (scales 2D scene + UI together) |
| Stretch aspect | `expand` (extra window space reveals more world/UI margin, never stretches or letterboxes) |
| Resizable | Yes |

## Save Slots (`SaveManager`)

| | Value |
|---|---|
| Number of slots | 3 |
| Save location | `user://saves/slot_N.json` |
| Legacy migration | A pre-slot-system `user://savegame.json`, if found, is moved into slot 1 on first boot |

## Grid Projection (`IsoUtils`)

| | Value |
|---|---|
| Tile width | 128 px |
| Tile height | 64 px |
| Projection | 2:1 dimetric ("AoE2-style"), not true isometric |
