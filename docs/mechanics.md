# Mechanics

How each system in the game currently works. For exact numbers, see [stats.md](stats.md).

## Resources

The town has a shared resource pool of many tracked resource types: **food, wood, stone**, plus the full crop-chain lineup — **grain, flour, bread, hops, beer, fruit, potato**. Food and wood start at 10; everything else starts at 0. Only Food, Wood, Stone, and Water get a dedicated row in the compact HUD panel today — the crop-chain resources are fully tracked and usable but not yet individually surfaced there.

Every resource is clamped independently between 0 and the town's **storage capacity** — filling up on food doesn't crowd out wood or stone, each has its own ceiling at the same shared value. There's a baseline capacity even with no storage buildings; a **Storage Facility** raises it further (see [stats.md](stats.md)). Hauling more into a full stockpile simply loses the overflow rather than refunding it — that's the intended cost of running out of storage, not a bug.

**Water** works differently: it isn't a depletable stockpile at all. A **Well** grants unlimited access rather than producing units of water, so the game just tracks whether at least one Well has been built (water available or not), not an amount.

## Population & Housing

The town has a population count and a population capacity. You start with 3 citizens and capacity for 3. Building a **House** raises capacity (not headcount); growing the population itself happens through Citizen Recruitment (see below), which is gated on having open capacity to grow into.

Every citizen eats continuously, once per second, whether or not they're doing any work — this is the only per-citizen upkeep cost right now. Hunger draws from any eatable resource — **food, then bread, then potato, then fruit**, in that priority order — rather than only plain "food," so a stocked bakery or orchard extends how long the town can go without a farm surplus. Grain, flour, hops, and beer are intermediate or luxury goods and can't be eaten directly; beer in particular is reserved as a future happiness-boosting luxury good rather than a calorie source.

## Gathering & Hauling

Production isn't instant or teleported — it's a physical loop of walking, working, and hauling.

**Assigning a citizen** to a workstation starts a dedicated work loop for that citizen. Each workstation accumulates what it produces in its own **output buffer**; nothing enters the shared resource pool until a citizen physically carries it to the stockpile (the Outpost Hall). There are three flavors of work loop, all sharing the same buffer/haul mechanics:

- **Converters (Farm and its crop-chain siblings)** turn a delivered input into an output. Each keeps an **input buffer** that a hauling trip tops up and drains a bit every production tick to make output. A haul trip fires whenever the post is about to run out of input to work with, or its output buffer is full — whichever happens first — so a single round trip usually drops off output and picks up more input in the same visit. The `Farm` class is a generic single-input/single-output converter under the hood (configurable input resource, output resource, and the skill it trains) — the original wood→food Farm, and every Alternative Crop Types building (Grain Farm, Mill, Bakery, Hops Farm, Brewery, Fruit Orchard, Potato Farm), are all just differently-configured instances of it sharing one work loop. A crop with no real input (Fruit Orchard, Potato Farm) simply sets its input requirement to 0, so it never waits on a delivery. See [stats.md](stats.md) for the full production chain.
- **Simple gatherers (Lumber Camp, Stone Mine)** produce output with no input requirement and haul a full load out once the output buffer hits its carry limit.
  - **Lumberjacks** specifically walk out to a nearby tree and chop it repeatedly rather than gathering in place — see Sustainable Forestry below.
  - **Stone Mine** workers use the plain generic loop: produce on a timer, haul when full. No special walking pattern.
- **Idle citizens aren't wasted.** A citizen with no assignment automatically looks for the single most valuable haul job across every workstation — either carrying a full output buffer to the stockpile, or carrying a needed input out to a workstation that's running short — and does that, then looks for the next one. This means idle workers passively do logistics for the rest of the town, including keeping Farms fed even without a dedicated hauler. Multiple haulers converging on the same starved post won't over-deliver past its capacity — a delivery re-checks the post's remaining space right before unloading and refunds any surplus to the stockpile instead of overshooting.

Multiple citizens can be assigned to the same workstation — they share that post's buffers and work in parallel rather than needing one dedicated hauler each.

## Sustainable Forestry

A Lumber Camp doesn't just deplete trees — it maintains a **target forest size** in the area around it. Before heading out to chop, a lumberjack checks whether the number of trees (mature or still growing) within the camp's search radius is under that target; if it is, they plant a sapling on open ground instead of chopping. This is a shared, area-wide target — any worker at the camp will top up the forest regardless of who personally chopped what down. Saplings take real time to grow to maturity (visibly scaling up) before they can be harvested. If a tree still has wood left when a chopper's carry limit caps out, it's left standing (not clear-cut) so someone can finish it later.

The map starts with a scattered forest of mature trees around the starting Lumber Camp so there's something to harvest immediately.

## Skills & Leveling

Every citizen has independent skill levels per activity (currently **farming**, **lumberjacking**, **mining**, **milling**, **baking**, and **brewing** — whatever post trains a skill is decided by the post type; wall-building doesn't train anything). The crop-chain buildings deliberately don't all train the same skill despite sharing a class — a Grain/Hops/Fruit/Potato farmer is training "farming," but running a Mill, Bakery, or Brewery is treated as a distinct trade. Skills run on a classic RuneScape-style 1–99 curve: early levels come fast, but the climb toward 99 is a long, flattening grind, matching the "long grind, many hours" design intent.

Every gather action (a production tick, a chop) grants a flat amount of experience regardless of the worker's current level or output — xp rewards time spent working, not skill already gained, so higher levels don't also compound their advantage through faster xp gain.

A higher skill level increases a worker's **output multiplier** at that activity — a maxed-level worker produces roughly 3x a level-1 worker. For a converter like the Farm, this multiplier applies equally to the output produced *and* the input consumed, so a more skilled worker moves more resources through the post each tick, but the input-to-output ratio never changes regardless of who's assigned.

## Happiness

Every citizen has a personal happiness value that continuously eases toward a target recomputed from current settlement conditions — it doesn't jump instantly, so a sudden change (the well running dry, a farm running out of food) is felt gradually over several ticks rather than all at once. The target rises with water access, rises further with food-equivalent stock on hand, rises again with food *variety* (more distinct edible resource types in stock), and drops sharply if the town has no food at all. Settlement happiness (shown on the HUD) is simply the average across every citizen.

A citizen whose happiness stays below the "unhappy" threshold for a sustained stretch leaves the settlement for good — this is the game's first mechanic where a resource shortfall has a consequence worse than production merely stalling. A citizen who leaves is a permanent loss for the current playthrough; nothing un-departs them short of reloading a save from before they left, same as any other town state a load reverts (loading a save is reverting to that point in time — a citizen who left *after* the loaded save was made reappears on load, since from the save's perspective they hadn't left yet).

## Citizen Recruitment

Clicking the Outpost Hall (rather than a citizen or a workstation) opens a recruitment panel offering 3 candidates, each with a name and a random specialization already trained to a meaningful starting level — a head start over a brand-new level-1 worker, not enough to out-level what's earned through play. Recruiting spends food and requires an open House slot (population capacity above the current population count); it's denied with a HUD message if either condition isn't met. A recruited citizen is added to the town exactly like the 3 starting citizens — same save/load handling, same happiness system, same eligibility for any post.

## Building & Placement

The **Build** button opens a menu of buildable options, each with a resource cost and a grid footprint. Selecting one drops a translucent "ghost" that follows the mouse, snapped to the isometric grid, tinted green if the spot is valid (in bounds, unoccupied, affordable) or red if not. Left-click confirms — spending the resources, reserving the footprint, and applying whatever passive bonus the building grants (population capacity, water access, or storage capacity). Buildings that can hold workers (Farm, Lumber Camp, Stone Mine, wall segments) automatically become assignable from the citizen task menu once placed; passive structures (House, Well, Storage Facility, Outpost Hall) never do.

Only one building occupies any grid cell — buildings and trees share the same occupancy grid, so neither can ever be placed on top of the other.

## Saving & Loading

Progress can be saved locally at any time and reloaded later (see [controls.md](controls.md) for the keys). A save captures: the full resource pool, population, water access, storage capacity, every tree in the world (position, maturity, remaining wood — a sapling mid-growth simply regrows from scratch on load rather than resuming at the exact same point), every player-placed building, everything sitting in workstation input/output buffers, and each citizen's skill progress and current work assignment. Loading merges saved resources onto the game's current resource list rather than replacing it wholesale, so an older save made before a resource type existed won't get stuck carrying over a stale value for it. There's no save-slot menu yet — it's a single local save file, overwritten each time.

## Camera

The camera is a free-scrolling top-down RTS camera over the isometric scene: scroll wheel to zoom, hold middle-mouse and drag to pan, or push the cursor to the edge of the screen to pan continuously. Panning and zooming are both bounded to the playable map, with a small margin beyond the edge so the view doesn't feel clipped right at the boundary.
