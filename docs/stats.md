# Stats Reference

Every concrete number currently in the game. Grouped by system; see [mechanics.md](mechanics.md) for how these numbers are used.

## Starting State

| | Value |
|---|---|
| Starting cabbage | 10 |
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
| Food-equivalent resources (drawn down for hunger, split evenly across whichever are in stock) | cabbage, potato, fruit, bread, beer ("Ale") |

## Resource Consumption

| | Value |
|---|---|
| Food (or food-equivalent) eaten per citizen | 0.2 / second |
| Consumption tick interval | every 1 second |
| Applies to | every citizen, regardless of work assignment |
| Floor | resources can't go below 0 |

## Buildings

| Building | Footprint | Cost | Grants | Notes |
|---|---|---|---|---|
| Outpost Hall | 2×2 | 20 wood | — | A stockpile drop-off/pickup point - haulers use whichever registered stockpile (any Outpost Hall or Storage Facility) is nearest. |
| Cabbage Farm | 2×2 | 6 wood | — | Converts wood → cabbage. See production table below. |
| Lumber Camp | 1×1 | 5 wood | — | Produces wood by chopping trees. See production table below. |
| House | 2×2 | 10 wood | +2 population capacity | Passive — no worker slot. Clickable once placed for a one-time upgrade: 15 stone for +2 more population capacity (denied if already upgraded or unaffordable). |
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
| Output resource | cabbage | wood | stone |
| Output per work cycle | 1.0 × skill multiplier | 2.0 × skill multiplier (per chop) | 0.5 × skill multiplier |
| Input resource | wood | — | — |
| Input cost per work cycle | 0.5 wood flat (not scaled by skill) | — | — |
| Work cycle interval | 1.5 s | 1.2 s (per chop) | 1.5 s |
| Carry limit (output buffer cap / haul size) | 6.0 | 6.0 | 6.0 |
| Search radius (tree-finding, Lumber Camp only) | — | 4.5 tiles | — |
| Target forest size maintained (Lumber Camp only) | — | 16 trees within search radius | — |
| Skill trained | `farming` | `lumberjacking` | `mining` |
| Max workers assigned at once | 1 | 1 | 1 |

## Worker Caps (`Workstation`)

| | Value |
|---|---|
| Max workers per Workstation (Farm-family, Lumber Camp, Stone Mine) | 1 |

Each post's status label shows live occupancy as `"<name>\n<active_workers>/<max_workers>"` (e.g. `"Lumber Camp 1/1"`), refreshed on every automatic assignment/unassignment. The Outpost Hall and Storage Facilities are never job posts - haulers are never explicitly "assigned" to either (see Automatic Job Assignment below), so they carry no worker count.

## Automatic Job Assignment (`Base`, `SkillTitles`)

| | Value |
|---|---|
| Job skills eligible for auto-assignment | farming, lumberjacking, mining, milling, baking, brewing, construction (`SkillTitles.TITLE_SKILLS`) |
| Matching algorithm | Citizen-proposing deferred acceptance (generalized Gale-Shapley), recomputed from scratch on every trigger |
| Triggers | Game boot/load, citizen recruited/departed, job post built/disabled/re-enabled |
| Swap condition | Strictly higher level in the contested skill only - ties never swap |
| Post disable toggle | Right-click any placed job post - evicts its current worker immediately, excluded from matching (0 capacity) until re-enabled |

The **Farm** class is a generic single-input/single-output converter (exported `input_per_tick`, `input_resource`, `skill_id`, `sprite_tint`) — the row above is its default configuration (wood → cabbage, "farming"). The full Alternative Crop Types chain is built from the same class, sharing one scene (`CropStation.tscn`) and distinguished only by catalog configuration:

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

## Skill Titles (`SkillTitles`)

Only the seven job skills (farming, lumberjacking, mining, milling, baking, brewing, construction) count - speed/strength are excluded, since they train passively and don't represent a trade.

| Level | Tier |
|---|---|
| 1 | Apprentice |
| 25 | Journeyman |
| 50 | Master |
| 75 | Grandmaster |
| 99 | Legendary |

Title = tier word (by whichever job skill is trained highest) + that skill's job noun (Farmer, Lumberjack, Miner, Miller, Baker, Brewer, Builder) - e.g. "Master Lumberjack". A tie at the same max level goes to whichever skill matches the citizen's current assignment, if any.

## Construction (`Base`, `ConstructionSite`, `Character`)

| | Value |
|---|---|
| Skill trained | `construction` |
| Materials delivery | Any idle/hauling citizen, same mechanism as output pickup/input delivery - see Gathering & Hauling |
| Labor required | `max(total units in the option's cost * 2.0, 10.0)` (`Base.LABOR_PER_MATERIAL_UNIT`/`MIN_LABOR_REQUIRED`) - e.g. a 5-wood Lumber Camp needs 10 labor (floor applies), a 25-wood+stone Storage Facility needs 50 |
| Labor added per work cycle | 1.0 (`Character.CONSTRUCTION_LABOR_PER_TICK`) × the worker's construction skill multiplier × the settlement's happiness output multiplier |
| Work cycle interval | 1.5 s (`Workstation.work_interval` default, unchanged for a construction site) |
| Max workers per site | 1 |
| What happens on completion | Site is freed; the real building is instantiated in its place and granted its capacity/water/storage bonus then, not at placement time; a fresh job-assignment pass runs immediately |
| What's spent, and when | The option's full cost, deducted resource-by-resource as each haul trip actually delivers it - nothing is spent at placement-confirm time |

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
| Displayed for | Wood, Stone (dedicated rows), and every food-family resource (aggregate + each of the collapsible breakdown's rows) |

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
| Candidates offered per visit | 3, distinct food tiers where possible |
| Food tiers (lowest to highest) | cabbage, potato, fruit, bread, beer ("Ale") |
| Cost per food type in a candidate's cost | 15 |
| Cost formula | 15 of the candidate's own tier's food, plus 15 of every cheaper tier's food (e.g. a bread-tier (index 3) candidate costs 15 cabbage + 15 potato + 15 fruit + 15 bread) |
| Starting level | 5 at tier 0 (cabbage), +5 per tier above that (5/10/15/20/25) |
| Possible specializations | farming, lumberjacking, mining, milling, baking, brewing, construction |
| Gated on | open population capacity, and affording that candidate's own (tier-scaled) cost |

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
