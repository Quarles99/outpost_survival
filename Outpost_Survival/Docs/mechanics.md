# Mechanics

How each system in the game currently works. For exact numbers, see [stats.md](stats.md).

## Resources

One shared pool, capped independently per resource type by storage capacity - filling up on one resource doesn't crowd out another. Overflow past capacity is lost, not refunded. Each resource shows a rolling income/minute rate reflecting what actually reached the stockpile (a workstation whose output is being lost to a full cap won't show positive income for it).

Every resource is represented by an icon (`scripts/resource_icons.gd`, `ResourceIcons.get_icon()`) rather than its name, in both the HUD's Wood/Stone rows and Food breakdown, and the Build menu's cost readout on each building button - the amount/rate numbers are still text, only the resource name itself is replaced.

Alongside the text Food row, a vertical Food bar in the HUD's bottom-right corner shows the aggregate food total as a fill against storage capacity - a graphical at-a-glance alternative, not a replacement. A red overlay band inside the top of the fill always shows the exact cost of the next meal (see Population & Housing below) whenever there's a population to feed - not a rate projection, since production arrives in discrete haul trips on a schedule unrelated to the day/night meal timing, so a smoothly-extrapolated growth preview wouldn't correspond to anything actually about to happen.

| Resource                            | Notes                                                                                                                 |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Wood, Stone                         | Raw materials                                                                                                         |
| Cabbage, Potato, Fruit, Bread, Beer | Food-equivalent - drawn down evenly for hunger                                                                        |
| Grain, Flour, Hops                  | Intermediate/luxury goods - tracked, not edible                                                                       |
| Brick                               | Worked stone (Brickmaker); used for upgrades and some buildings                                                       |
| Water                               | A Well grants unlimited access - tracked as available or not, not an amount. Boosts Farm-family output (see stats.md) |

## Population & Housing

Population count and capacity are tracked separately: a House raises capacity, Citizen Recruitment (below) grows the headcount into it. A placed House can be upgraded once for more capacity (see stats.md for cost). Every citizen eats exactly twice per day/night cycle - once at dawn, once at dusk (see Day & Night below) - regardless of work assignment, the only per-citizen upkeep right now. Each meal draws evenly across whichever food-equivalent resources are currently in stock, redistributing across the rest if one runs dry mid-meal.

## Assigning Citizens

Job assignment is fully automatic - clicking a citizen only selects them, opening a view-only skill panel (click again, or elsewhere, to deselect). A citizen's floating name/title only appears while they're selected, to keep the settlement from being cluttered with text at all times. Each citizen takes whichever job trains the skill they're currently best at, re-evaluated whenever a citizen arrives/leaves, a post is built/disabled/re-enabled, or a save loads. A citizen with no open matching post hauls instead until one opens up. A fully-staffed post only swaps in a new citizen on a *strictly* higher skill level than its weakest occupant - ties never trigger a swap.

Any placed job post can be right-clicked to disable it - evicts its worker immediately and blocks auto-staffing until re-enabled (shown as "(Disabled)", dimmed).

## Gathering & Hauling

Production is a physical loop, not instant: walk, work, haul. Each workstation buffers its own output (and input, for converters) - nothing reaches the shared pool until a citizen carries it to the nearest registered stockpile (Outpost Hall or Storage Facility).

| Work type | Buildings | Behavior |
| --- | --- | --- |
| Converter | Farm-family (Farm + every Alternative Crop Type), Brickmaker | Drains an input buffer to produce output; hauls when input runs low or output is full, often both in one trip |
| Simple gatherer | Lumber Camp, Stone Mine | No input needed; hauls a full load once output caps out. Lumberjacks specifically walk to and chop a live tree (see Sustainable Forestry) rather than gathering in place |
| Training | Barracks, Archery Range, Mage Tower | No input or output at all, nothing to haul - pure time-worked xp toward a combat skill (see Skills & Leveling) |
| Automatic hauler | Any idle citizen, or a dedicated worker with nothing to do right now | Picks whichever haul job (output pickup, input delivery, or construction-site delivery) is most needed across every post |

Multiple citizens can share a post up to its worker cap (see stats.md); status labels show live occupancy (e.g. "Lumber Camp 1/1"). Every production tick spawns a brief floating "+1.2 Cabbage +4 xp" text at the worker's feet.

When several construction sites need the same resource at once and there isn't enough to go around, haulers finish whichever site needs the *least* first, not whichever needs the most - this matters at the start of a new game (see Citizen Recruitment/Building & Placement below): starting wood only covers a Lumber Camp, so a player who also places a Cabbage Farm and House right away will see the Lumber Camp get built first regardless, guaranteeing a wood supply exists before the bigger, more wood-hungry buildings compete for it.

## Pathfinding

Citizens route around buildings and trees rather than cutting through them - the same `NavigationAgent2D`-driven approach the Battle Test sandbox already used, ported to the settlement. The navmesh re-bakes automatically whenever a building is placed/completed or a tree is planted/harvested, so pathing always reflects the current layout. Unlike combat, citizens don't dodge each other while walking (no agent-vs-agent avoidance) - only the map's fixed obstacles.

## Sustainable Forestry

A Lumber Camp maintains a target forest size within its search radius (see stats.md) rather than depleting trees outright - a lumberjack plants a sapling instead of chopping if the local tree count (mature + growing) is under target. Saplings take real time to mature before they're harvestable. A tree with wood left when a chopper's carry limit caps out is left standing, not clear-cut.

## Skills & Leveling

Every citizen levels independently per skill on a RuneScape-style 1-99 curve - fast early levels, a long flattening grind to 99 (see stats.md).

| Skill type | Skills | Trained by |
| --- | --- | --- |
| Job skills | farming, lumberjacking, mining, masonry, milling, baking, brewing, construction | Whatever post the citizen is currently assigned to |
| Combat skills | melee_combat, archery, spellcasting | Barracks / Archery Range / Mage Tower - trains the skill and directly scales that citizen's stats when deployed (see Battle Deployment below) |
| Passive skills | speed, strength | Speed: time spent moving. Strength: completing a haul trip. Trained regardless of assignment |

A resource-producing action (farming/lumberjacking/mining/masonry/milling/baking/brewing) grants xp proportional to the amount actually produced that tick - a higher skill level scales *output*, and now xp along with it, so leveling up compounds rather than staying flat. To keep pace-to-next-level from also compounding on top of that, the xp *required* per level scales up by that same per-level factor (see stats.md) - the number of actions needed to clear a level is unchanged from a flat-xp scheme, only the raw numbers involved are bigger at high level. Construction labor, training drill, and the passive speed/strength skills still grant flat xp per action - none of those represent a real resource amount to scale against. Each citizen shows their highest-trained job skill (job or combat) as a title (tier + job noun, e.g. "Master Lumberjack", "Apprentice Soldier" - see stats.md for tiers).

## Battle Deployment

The HUD's **Simulate Attack** button is the current stand-in for a real raid/siege trigger (there's no wandering-raider AI yet - see roadmap.md's Long-Term Design Vision). Every citizen currently assigned to a Barracks, Archery Range, or Mage Tower deploys as their own squad to the battle scene (the same sandbox reachable from the main menu's "Battle Test") against a generated enemy raiding party, using each citizen's real trained combat-skill level rather than a random one. A citizen not currently stationed at one of those three buildings never deploys - "soldier" is just whatever a citizen's current post happens to be, same as any other job.

A `melee_combat`-trained citizen's concrete battlefield role (Shieldbearer/Marauder/Outrider/Trapper) is assigned round-robin, since the skill itself doesn't distinguish between the four - a first-pass simplification, not a player choice yet. The rest of the fight plays out exactly like the standalone sandbox (formations, AI, morale/routing).

Returning to the settlement (automatic once the fight ends, or immediately on Esc to retreat early) restores the town exactly as it was left and reports the outcome plus any losses. A citizen who dies in battle doesn't come home - permanent, same as a sustained-unhappiness departure. A citizen who routs/flees always survives and returns, regardless of the battle's outcome.

## Happiness

Each citizen's happiness eases gradually toward a target set by water access, food stock, and food variety (see stats.md for exact bonuses) - a sudden change is felt over several ticks, not instantly. Settlement happiness (HUD) is the town average, and falls into one of four bands (Thriving/Content/Unhappy/Miserable) that apply a flat production multiplier on top of a worker's own skill (see stats.md). A citizen whose happiness stays below the unhappy threshold long enough leaves the settlement permanently - the only mechanic where a shortfall costs more than stalled production.

## Day & Night

A day/night clock runs continuously in the background (see stats.md for exact durations) - the HUD shows the current day number and whether it's day or night, and the world tints toward dusk-blue at night, easing back at dawn. Food consumption is tied to this clock (see Population & Housing above) - a flat meal is charged at both the dawn and dusk transitions. Nothing about work speed or hauling changes with the cycle yet; it's still the foundation for later mechanics (roadmap.md's Long-Term Design Vision), not a finished day/night economy.

## Citizen Recruitment

Clicking the Outpost Hall offers 3 recruit candidates, drawn from distinct food tiers where possible. A higher-tier candidate starts more skilled but costs its own tier's food plus every cheaper tier's (see stats.md for the formula), so no food type goes obsolete once a fancier one comes online. Recruiting needs an open House slot and enough of the required food; a recruited citizen behaves identically to a starting one.

Recruiting is also capped at once per day (see Day & Night above) - clicking the Outpost Hall while on cooldown shows how many days remain instead of opening the candidate panel. The cooldown length is a single settable value, meant to be lowered by a future upgrade; nothing lowers it yet.

A built Barracks/Archery Range/Mage Tower each offer their own additional recruit once per day, on top of the Outpost Hall's, plus a repeatable Upgrade - clicking one opens a small panel with both options rather than jumping straight to a recruit candidate. Recruit (if not on its own cooldown) offers a single candidate already trained in that building's combat skill (Soldier/Archer/Mage), at the cheapest food-tier cost. Upgrade spends brick to raise that specific building's worker cap by 3 (starting at 3, uncapped) - see stats.md's Military Building Unit Cap. Each of the three building types is still capped at one built at a time, since each independently grants its own extra recruit.

## Building & Placement

The Build button opens a numbered grid of buildable options; picking one drops a placement ghost that snaps to the grid, tinted green (valid) or red (out of bounds, occupied, or unaffordable). Left-click confirms and starts a construction site (see below), not an instant building. Buildings, sites, and trees all share one occupancy grid - nothing overlaps.

Starting wood only covers a Lumber Camp - the Cabbage Farm and House both have to be earned by actually running it for a while first, a deliberate early-game pace-setter (see stats.md's Starting State). A placement ghost only checks *momentary* stock, though, so a player can place all three right away if they want - the Farm and House's construction sites will just sit waiting on materials until the Lumber Camp is built, staffed, and producing (see Gathering & Hauling above for how haulers prioritize a scarce resource across several waiting sites).

Any placed Farm-family building can be clicked to retool into a different Farm-family recipe, free and instant - the building, footprint, and any assigned worker stay put, only the recipe changes (buffered goods under the old recipe are cleared, not converted). Brickmaker is not part of this group - it's a dedicated single-recipe building. Only Cabbage Farm is placeable from the Build menu - Grain Farm/Hops Farm/Fruit Orchard/Potato Farm exist purely as retool targets now (per an explicit request to combine the five separate crop buildings into one buildable building), never placed directly.

## Construction

Confirming a placement starts a construction site, not a finished building, in two phases:

1. **Materials** - any idle/hauling citizen delivers the option's full cost, the same as any other haul job. Nothing is spent from the stockpile until it actually arrives; the site sits half-supplied indefinitely if materials run out. Its label shows what's still needed.
2. **Labor** - once materials are complete, the site becomes a normal job post training Construction, staffed automatically like any other job (preferring the highest Construction skill), and can take up to several builders at once - each additional one adds to build speed, but at reduced effectiveness per worker rather than linearly (see stats.md). Labor required scales with the building's total material cost (see stats.md). Label shows percent complete.

Completing labor replaces the site with the real building on the spot, granting its capacity/water/storage bonus then, not at placement time. Progress (materials delivered + labor completed) survives save/load.

## Main Menu & Save/Load

The game opens on a main menu: **Continue** loads the most recently saved slot; **New Game**/**Load Game** open a slot picker (3 slots, showing timestamp + population). In-game, the same picker is reachable via the System Menu (Esc, or the HUD's Menu button) without returning to the main menu - whichever slot is picked there becomes the active slot for `F5`/`F9` quicksave/quickload too (see [controls.md](controls.md)).

A save captures the full resource pool, population, water access, storage capacity, every tree, every building (including retooling), workstation buffers, and each citizen's exact position, skills, and assignment. Starting a new game always resets to a clean slate.

## Camera

Free-scrolling top-down RTS camera: scroll wheel zooms, middle-mouse drag pans, cursor-at-edge pans continuously. Panning and zooming are both bounded to the playable map with a small margin past the edge (see stats.md).

## Fast Forward

Citizens walk and work at half their original pace (see stats.md for exact numbers) - a deliberate slowdown to make the settlement feel less rushed. Food consumption per citizen was halved to match (see stats.md#resource-consumption) - production already slowed down for free from the longer work cycle alone, so consumption needed its own cut to keep the same production/consumption ratio the game was originally balanced around, rather than quietly making food tighter. The HUD's Speed button (or `+`/`-`) cycles 1x/2x/4x to compress that back down when there's nothing to react to; it speeds up everything uniformly (movement, work, hunger, happiness, the day/night clock), not just one system, and always resets to 1x on leaving the settlement.
