# Roadmap

Tracks what's implemented vs. what's planned. Source of truth for "what's next" is `/Implement_Next.txt` at the repo root — this page restates it in plain language and folds in the longer-term vision from `/Outpost Survival Game Ideas`. Updated whenever an item there is marked `[DONE]`.

## Implemented

- **Save & load.** 3 numbered local slots, no cloud sync. Covers resources, population, water, storage, trees, buildings, workstation buffers, and each citizen's skills/job. See [mechanics.md](mechanics.md#main-menu--saveload).
- **Realistic travel & labor.** Citizens physically walk and haul rather than gathering instantly; trees are sustainably managed, not a one-time deposit; idle citizens double as general haulers. See [mechanics.md](mechanics.md#gathering--hauling).
- **Water resource.** A Well grants unlimited access rather than a depletable stockpile - tracked as available/not. See [mechanics.md](mechanics.md#resources).
- **Stone resource.** Mined with no input requirement; currently only spent on the Well and Storage Facility.
- **Storage facility.** Resources are capped per-type; a facility raises the cap. Overflow is lost, not refunded. See [stats.md](stats.md#resource-storage).
- **Alternative crop types.** Full grain→flour→bread and hops→beer chains, plus fruit/potato/cabbage as wood-input crops - all share one generalized converter class. See [stats.md](stats.md#workstation-production).
- **Happiness system.** Per-citizen happiness eases toward a target from water/food/variety; sustained low happiness costs a citizen permanently. See [mechanics.md](mechanics.md#happiness).
- **Citizen recruitment.** Outpost Hall offers 3 candidates with pre-trained specializations, costing food. See [mechanics.md](mechanics.md#citizen-recruitment).
- **Resource income/minute.** HUD rows show a rolling net rate alongside the current amount.
- **Condensed build menu.** Numbered grid of solid-color, tinted buttons instead of a full-width list; applies to the crop-retool panel too.
- **Larger map.** 28×28 tiles, 4x the original size.
- **Speed and strength skills.** Passive, trained regardless of assignment - speed from moving, strength from hauling. See [mechanics.md](mechanics.md#skills--leveling).
- **Happiness bonuses/debuffs.** Four named bands apply a flat production multiplier on top of skill. See [mechanics.md](mechanics.md#happiness).
- **Per-farm crop selection.** Any Farm-family building can be retooled into another recipe, free and instant. See [mechanics.md](mechanics.md#building--placement).
- **Worker caps.** Every Workstation caps at 1 assigned worker.
- **Skill panel.** Clicking a citizen opens a view-only skill panel instead of an assignment menu (assignment is now fully automatic). See [mechanics.md](mechanics.md#assigning-citizens).
- **Main menu with save/load UI.** Boots into a menu (Continue/New Game/Load Game/Quit); in-game System Menu offers the same slot picker. See [controls.md](controls.md).
- **Distinct crop-chain skills.** Mill/Bakery/Brewery each train their own skill rather than sharing "farming." See [mechanics.md](mechanics.md#skills--leveling).
- **Water farming bonus.** Farm-family output +25% once a Well is built. See [stats.md](stats.md#water-farming-bonus-character).
- **Multi-stockpile hauling.** Any Storage Facility is a real drop-off/pickup point, not just a capacity bump - haul trips go to the nearest one. See [mechanics.md](mechanics.md#gathering--hauling).
- **Resizable game window.** Scales without stretching or distorting. See [stats.md](stats.md#display-projectgodot).
- **Minimal starting buildings.** Only the Outpost Hall starts built.
- **Live worker-slot labels.** Every post shows filled/max occupancy, updating immediately. See [mechanics.md](mechanics.md#gathering--hauling).
- **Floating gather feedback.** A brief "+1.2 Food +4 xp" text floats at the worker's feet each production tick.
- **House upgrade.** One-time stone/brick-funded upgrade for +2 more population capacity. See [mechanics.md](mechanics.md#population--housing).
- **Skill titles.** Every citizen carries an earned title (Apprentice→Legendary, paired with their best job skill). See [mechanics.md](mechanics.md#skills--leveling).
- **Automatic job assignment.** Manual assignment is gone - citizens auto-take the best-matching open post, displacing a weaker incumbent on arrival; any post can be right-click disabled. See [mechanics.md](mechanics.md#assigning-citizens).
- **Combat training buildings.** Barracks/Archery Range/Mage Tower train melee_combat/archery/spellcasting exactly like any other job post (no input/output, pure time-worked xp). See [mechanics.md](mechanics.md#skills--leveling).
- **Battle deployment.** The HUD's "Simulate Attack" button deploys every citizen assigned to a combat-training building into the Battle Test sandbox, using their real trained skill level, against a generated enemy raiding party - town state is preserved and restored around the fight, and a citizen who dies doesn't come home. Still a manual trigger, not a real raid/siege system - see [mechanics.md](mechanics.md#battle-deployment).
- **Day/night cycle.** A background clock (8-minute day, 4-minute night) with a HUD counter and a world tint - foundation for food consumption/work-schedule mechanics down the line, not wired to either yet. Currently drives one real mechanic: recruiting is capped to once per day. See [mechanics.md](mechanics.md#day--night).
- **Slower pace + fast forward.** Citizen movement and work both run at half their original speed, with food consumption halved to match so the economy stays in balance; a HUD Speed button (or `+`/`-`) cycles 1x/2x/4x to compress that back down. See [mechanics.md](mechanics.md#fast-forward).
- **Early-game pace via gathering.** Starting wood only covers a Lumber Camp - the first Cabbage Farm and House both have to be earned through real wood gathering rather than affordable on turn one. Originally tuned so a first House lands roughly a third to halfway through Day 1; building costs and the Lumber Camp's own gather rate have both since moved via [[Balance]] edits, not re-verified against that target since. See [mechanics.md](mechanics.md#building--placement).
- **Periodic meal consumption.** Food upkeep is now two flat meals per day/night cycle (dawn and dusk) instead of a continuous per-second drain, tied to the day/night clock. See [mechanics.md](mechanics.md#population--housing).
- **Food bar (HUD).** A vertical fill-bar alternative to the text Food row, with a red overlay showing the next meal's exact cost and a green overlay previewing the next 30 seconds of production gain. See [mechanics.md](mechanics.md#resources).
- **Output-scaled xp.** Resource-production actions now grant xp proportional to output instead of a flat amount, with the xp curve's own requirements scaled to match so level-up pacing is unchanged. See [mechanics.md](mechanics.md#skills--leveling).
- **Combat-building recruits.** A built Barracks/Archery Range/Mage Tower each offer one additional recruit per day, pre-trained in that building's own combat skill, on an independent cooldown from the Outpost Hall's - each capped at one built at a time. See [mechanics.md](mechanics.md#citizen-recruitment).
- **Military building unit cap.** Barracks/Archery Range/Mage Tower each start with a worker cap of 3 (rather than the usual 1) and can be repeatedly upgraded with brick for +3 more each time, uncapped. See [stats.md](stats.md#military-building-unit-cap-trainingground-base).
- **Town pathfinding.** Citizens navigate around buildings/trees via `NavigationAgent2D`, the same system the Battle Test sandbox uses - the navmesh re-bakes on every building/tree change. See [mechanics.md](mechanics.md#pathfinding).

## Planned Next (from `Implement_Next.txt`)

Nothing is currently queued - every item in `Implement_Next.txt` has been implemented (see above). Add new entries there to populate this list again.

## Long-Term Design Vision

From the original design notes (`Outpost Survival Game Ideas`) — not scheduled, but the direction the game is meant to grow toward:

- A large explorable world with multiple possible base sites, not just the single fixed base that exists today.
- Recruiting citizens with varied skills (today's 3 starting citizens are functionally identical aside from independently-trained levels).
- Securing off-base resources on the wider map as supplemental income.
- A simulated world economy, and other settlements to befriend or destroy.
- Import/export via armed caravans — trade is deliberately risky given a dangerous world.
- Base defense against random raids/sieges from aggressive wildlife and hostile settlers.
- A specialization-driven skill system spanning both combat and labor, where the max achievable total level deliberately can't cover every skill — forces build choices per citizen.
- Perma-death for citizens, softened by (unspecified-so-far) ways to minimize lethality.
- Grimdark medieval-fantasy tone: mostly grounded combat, with rare, powerful, and unsettling magic — inspired by State of Decay 2, Warcraft 3, Age of Empires 2, Project Zomboid, RuneScape, and Battle Brothers.
