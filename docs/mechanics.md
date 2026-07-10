# Mechanics

How each system in the game currently works. For exact numbers, see [stats.md](stats.md).

## Resources

The town has a shared resource pool of many tracked resource types: **food, wood, stone**, plus the full crop-chain lineup — **grain, flour, bread, hops, beer, fruit, potato**. Food and wood start at 10; everything else starts at 0. Only Food, Wood, Stone, and Water get a dedicated row in the compact HUD panel today — the crop-chain resources are fully tracked and usable but not yet individually surfaced there.

Every resource is clamped independently between 0 and the town's **storage capacity** — filling up on food doesn't crowd out wood or stone, each has its own ceiling at the same shared value. There's a baseline capacity even with no storage buildings; a **Storage Facility** raises it further (see [stats.md](stats.md)). Hauling more into a full stockpile simply loses the overflow rather than refunding it — that's the intended cost of running out of storage, not a bug.

Each displayed resource also shows a rolling **income/minute** rate next to its amount — net change over roughly the last minute (shorter right after boot), not an instantaneous snapshot, so a single big haul-trip deposit doesn't make the rate spike and vanish a second later. It measures what actually reached the stockpile, so a workstation whose output is being lost to a full storage cap won't show a positive rate for it.

**Water** works differently: it isn't a depletable stockpile at all. A **Well** grants unlimited access rather than producing units of water, so the game just tracks whether at least one Well has been built (water available or not), not an amount. Water access also boosts every Farm-family building's output for the same input cost — more food/crops per unit of wood or intermediate good spent, not a discount on the input itself.

## Population & Housing

The town has a population count and a population capacity. You start with 3 citizens and capacity for 3. Building a **House** raises capacity (not headcount); growing the population itself happens through Citizen Recruitment (see below), which is gated on having open capacity to grow into.

Every citizen eats continuously, once per second, whether or not they're doing any work — this is the only per-citizen upkeep cost right now. Hunger draws from any eatable resource — **food, then bread, then potato, then fruit**, in that priority order — rather than only plain "food," so a stocked bakery or orchard extends how long the town can go without a farm surplus. Grain, flour, hops, and beer are intermediate or luxury goods and can't be eaten directly; beer in particular is reserved as a future happiness-boosting luxury good rather than a calorie source.

## Assigning Citizens

Clicking a citizen selects them and opens a skill panel showing all of their skill levels — there's no separate task menu. With a citizen selected, clicking a workstation or wall segment assigns them there (denied with a message if that post is already full); clicking the same, already-selected citizen again unassigns them instead. Dragging a citizen straight onto a post assigns them without selecting first. Either way, assignment doesn't interrupt what a citizen was already doing mid-task beyond the reassignment itself — see Gathering & Hauling below for what happens once they arrive.

The Outpost Hall and any Storage Facility are also valid assignment targets, either by dragging a citizen onto one or selecting them and clicking it. This explicitly designates that citizen as a hauler — the same logistics work an unassigned citizen already does automatically, just as a deliberate, visible, savable assignment (shown as "Hauling" in their status) rather than only ever an implicit fallback for having nothing else to do.

## Gathering & Hauling

Production isn't instant or teleported — it's a physical loop of walking, working, and hauling.

**Assigning a citizen** to a workstation starts a dedicated work loop for that citizen. Each workstation accumulates what it produces in its own **output buffer**; nothing enters the shared resource pool until a citizen physically carries it to a stockpile. The Outpost Hall is always one; every placed Storage Facility is too — a haul trip always goes to whichever registered stockpile is nearest to the citizen at the time, so building a Storage Facility near a cluster of workstations genuinely shortens their haul trips rather than only raising the storage cap. There are three flavors of work loop, all sharing the same buffer/haul mechanics:

- **Converters (Farm and its crop-chain siblings)** turn a delivered input into an output. Each keeps an **input buffer** that a hauling trip tops up and drains a bit every production tick to make output. A haul trip fires whenever the post is about to run out of input to work with, or its output buffer is full — whichever happens first — so a single round trip usually drops off output and picks up more input in the same visit. The `Farm` class is a generic single-input/single-output converter under the hood (configurable input resource, output resource, and the skill it trains) — the original wood→food Farm, and every Alternative Crop Types building (Grain Farm, Mill, Bakery, Hops Farm, Brewery, Fruit Orchard, Potato Farm), are all just differently-configured instances of it sharing one work loop. A crop with no real input (Fruit Orchard, Potato Farm) simply sets its input requirement to 0, so it never waits on a delivery. See [stats.md](stats.md) for the full production chain.
- **Simple gatherers (Lumber Camp, Stone Mine)** produce output with no input requirement and haul a full load out once the output buffer hits its carry limit.
  - **Lumberjacks** specifically walk out to a nearby tree and chop it repeatedly rather than gathering in place — see Sustainable Forestry below.
  - **Stone Mine** workers use the plain generic loop: produce on a timer, haul when full. No special walking pattern.
- **Idle citizens aren't wasted.** A citizen with no assignment automatically looks for the single most valuable haul job across every workstation — either carrying a full output buffer to the stockpile, or carrying a needed input out to a workstation that's running short — and does that, then looks for the next one. This means idle workers passively do logistics for the rest of the town, including keeping Farms fed even without a dedicated hauler. Multiple haulers converging on the same starved post won't over-deliver past its capacity — a delivery re-checks the post's remaining space right before unloading and refunds any surplus to the stockpile instead of overshooting.
- **A blocked worker helps out too.** A dedicated worker isn't just idle when their own post has nothing for them right now (a Farm-family worker waiting on an input delivery that didn't fully restock, or a Lumberjack finding no available tree in range) — they run the same haul-job search idle citizens use and help elsewhere for one trip before checking back on their own post, rather than standing around waiting.

Multiple citizens can be assigned to the same workstation — they share that post's buffers and work in parallel rather than needing one dedicated hauler each — up to a per-post worker cap (see [stats.md](stats.md)); once full, that post no longer shows up as an assignment option for another citizen. A wall segment is the exception, capped at a single defender.

## Sustainable Forestry

A Lumber Camp doesn't just deplete trees — it maintains a **target forest size** in the area around it. Before heading out to chop, a lumberjack checks whether the number of trees (mature or still growing) within the camp's search radius is under that target; if it is, they plant a sapling on open ground instead of chopping. This is a shared, area-wide target — any worker at the camp will top up the forest regardless of who personally chopped what down. Saplings take real time to grow to maturity (visibly scaling up) before they can be harvested. If a tree still has wood left when a chopper's carry limit caps out, it's left standing (not clear-cut) so someone can finish it later.

The map starts with a scattered forest of mature trees around the starting Lumber Camp so there's something to harvest immediately.

## Skills & Leveling

Every citizen has independent skill levels per activity (currently **farming**, **lumberjacking**, **mining**, **milling**, **baking**, and **brewing** — whatever post trains a skill is decided by the post type; wall-building doesn't train anything). The crop-chain buildings deliberately don't all train the same skill despite sharing a class — a Grain/Hops/Fruit/Potato farmer is training "farming," but running a Mill, Bakery, or Brewery is treated as a distinct trade. Skills run on a classic RuneScape-style 1–99 curve: early levels come fast, but the climb toward 99 is a long, flattening grind, matching the "long grind, many hours" design intent.

Every gather action (a production tick, a chop) grants a flat amount of experience regardless of the worker's current level or output — xp rewards time spent working, not skill already gained, so higher levels don't also compound their advantage through faster xp gain.

A higher skill level increases a worker's **output multiplier** at that activity — a maxed-level worker produces roughly 3x a level-1 worker. For a converter like the Farm, this multiplier applies equally to the output produced *and* the input consumed, so a more skilled worker moves more resources through the post each tick, but the input-to-output ratio never changes regardless of who's assigned.

Two more skills, **speed** and **strength**, work differently from the rest: every citizen trains them passively just by existing, regardless of what post (if any) they're assigned to, rather than needing a specific job to train. Speed raises movement speed and is trained by the act of moving — xp is proportional to time spent walking, not a flat amount per trip, so a faster citizen doesn't out-level a slower one just by finishing more trips in the same time. Strength raises how much a citizen can carry in a single haul trip (starting from a workstation's own base carry limit) and is trained once per haul trip that actually moved something, whichever direction. A stronger, faster citizen needs fewer round trips to keep a workstation fed and hauls fuller loads out to the stockpile.

## Happiness

Every citizen has a personal happiness value that continuously eases toward a target recomputed from current settlement conditions — it doesn't jump instantly, so a sudden change (the well running dry, a farm running out of food) is felt gradually over several ticks rather than all at once. The target rises with water access, rises further with food-equivalent stock on hand, rises again with food *variety* (more distinct edible resource types in stock), and drops sharply if the town has no food at all. Settlement happiness (shown on the HUD) is simply the average across every citizen.

A citizen whose happiness stays below the "unhappy" threshold for a sustained stretch leaves the settlement for good — this is the game's first mechanic where a resource shortfall has a consequence worse than production merely stalling. A citizen who leaves is a permanent loss for the current playthrough; nothing un-departs them short of reloading a save from before they left, same as any other town state a load reverts (loading a save is reverting to that point in time — a citizen who left *after* the loaded save was made reappears on load, since from the save's perspective they hadn't left yet).

Settlement happiness also falls into one of four named bands — Thriving, Content, Unhappy, Miserable (shown next to the percentage on the HUD) — each applying a flat production bonus or debuff on top of whatever the worker's own skill would produce. It only affects output, not the input a converter like a Farm consumes, so an unhappy settlement doesn't eat less — it just wastes more material producing less from it, reading as carelessness rather than a change in appetite.

## Citizen Recruitment

Clicking the Outpost Hall (rather than a citizen or a workstation) opens a recruitment panel offering 3 candidates, each with a name and a random specialization already trained to a meaningful starting level — a head start over a brand-new level-1 worker, not enough to out-level what's earned through play. Recruiting spends food and requires an open House slot (population capacity above the current population count); it's denied with a HUD message if either condition isn't met. A recruited citizen is added to the town exactly like the 3 starting citizens — same save/load handling, same happiness system, same eligibility for any post.

## Building & Placement

The **Build** button opens a menu of buildable options as a grid of square buttons (numbered `1`-`9` for the first nine) — each one a solid color (the building's tint, or a neutral default) with its name in bold centered text, since the actual in-world building art is either shared between several buildings (differing only by tint) or too detailed to read at button size; hover one for its full name and cost. Selecting one drops a translucent "ghost" that follows the mouse, snapped to the isometric grid, tinted green if the spot is valid (in bounds, unoccupied, affordable) or red if not. Left-click confirms — spending the resources, reserving the footprint, and applying whatever passive bonus the building grants (population capacity, water access, or storage capacity). Buildings that can hold workers (Farm, Lumber Camp, Stone Mine, wall segments) automatically become assignable once placed (see Assigning Citizens above); passive structures (House, Well, Storage Facility, Outpost Hall) never do.

Only one building occupies any grid cell — buildings and trees share the same occupancy grid, so neither can ever be placed on top of the other.

**Retooling a Farm-family building.** Every Alternative Crop Types building (and the original wood→food Farm) shares one underlying class, so any of them can be freely reconfigured into any other after the fact — click an already-placed one to open a panel of every Farm-family recipe and pick a different one. It's free and instant, not a rebuild: the building, its footprint, and any assigned worker all stay exactly as they were, and a worker already assigned just starts producing the new recipe on their next production tick with no interruption. Whatever was sitting in that building's input/output buffers under the old recipe is cleared, not carried over or converted.

## Main Menu & Save/Load

The game opens on a main menu rather than straight into the base: **Continue** loads whichever of the 3 save slots was saved most recently, without asking which one; **New Game** and **Load Game** open a slot picker showing each slot's status (empty, or a timestamp and population count) and start fresh in, or load, whichever one is picked. Starting a new game always begins from a clean slate — the starting resources, population, and the 3 starting citizens' skill progress are all reset, even if a previous game was played earlier in the same session.

In-game, the same slot picker is reachable without returning to the main menu, via a System Menu (**Esc**, when nothing else is selected or open, or the HUD's **Menu** button): Save, Load, back to the Main Menu, or Quit. Whichever slot is picked there becomes the active one for `F5`/`F9` quicksave/quickload too (see [controls.md](controls.md)), so they stay in sync with whatever was last saved or loaded through the menu.

A save captures: the full resource pool, population, water access, storage capacity, every tree in the world (position, maturity, remaining wood — a sapling mid-growth simply regrows from scratch on load rather than resuming at the exact same point), every player-placed building (including any Farm-family retooling), everything sitting in workstation input/output buffers, and each citizen's exact position, skill progress, and current work assignment — a citizen mid-haul-trip when saved reappears exactly where they were on load rather than snapping back to their post. Loading merges saved resources onto the game's current resource list rather than replacing it wholesale, so an older save made before a resource type existed won't get stuck carrying over a stale value for it.

## Camera

The camera is a free-scrolling top-down RTS camera over the isometric scene: scroll wheel to zoom, hold middle-mouse and drag to pan, or push the cursor to the edge of the screen to pan continuously. Panning and zooming are both bounded to the playable map, with a small margin beyond the edge so the view doesn't feel clipped right at the boundary.
