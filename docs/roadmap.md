# Roadmap

Tracks what's implemented vs. what's planned. Source of truth for "what's next" is `/Implement_Next.txt` at the repo root — this page restates it in plain language and folds in the longer-term vision from `/Outpost Survival Game Ideas`. Updated whenever an item there is marked `[DONE]`.

## Implemented

**Save & load.** Local save/load (see [controls.md](controls.md) for `F5`/`F9`) covering resources, population, water access, storage capacity, every tree, every player-placed building, workstation buffers, and each citizen's skill progress and current job. One fixed local slot, no menu yet. Cloud sync is a stated future goal, not started.

**Realistic travel & labor.** Gathering is no longer instant/passive — citizens physically walk to workstations and haul goods to and from the stockpile (the Outpost Hall), with buffered output/input and per-post carry limits. Movement and work speed were deliberately slowed to read as "slow but consistent" rather than twitchy. Trees are a shared, sustainably-managed resource (Lumber Camps replant toward an area-wide target) rather than a one-time deposit. Idle citizens double as general haulers, picking whichever job (an output pickup or an input delivery) moves the most material across every workstation, with overshoot protection when multiple haulers converge on the same starved post. See [mechanics.md](mechanics.md#gathering--hauling) for the full loop.

**Water resource.** A Well (built from stone + wood) grants unlimited water access rather than a depletable stockpile — the game just tracks whether water is available, not an amount. Not consumed by anything yet; the planned Happiness system below is what will eventually care whether a settlement has water.

**Stone resource.** A Stone Mine produces stone with no input requirement, using the same generic produce-and-haul loop as any simple gatherer. Nothing costs stone except the Well and Storage Facility yet — a proper stone-consuming building lineup (walls, upgrades) is still to come.

**Storage facility.** Resources are now capped (they weren't before) — each resource type independently caps at a shared "storage capacity" value, 30 by default even with no facilities built. A Storage Facility adds +30 more, and multiple can be built for cumulative capacity. Overflow past capacity is lost rather than refunded, which is an intentional consequence of the cap existing, not a bug. Not yet upgradeable in place (build another facility instead) — that needs a building-selection interaction that doesn't exist for passive structures yet.

**Alternative crop types.** The full grain→flour→bread and hops→beer refinement chains, plus fruit and potato as simple no-input crops, are all buildable now (Grain Farm, Mill, Bakery, Hops Farm, Brewery, Fruit Orchard, Potato Farm — see [stats.md](stats.md#workstation-production) for the full chain). Rather than seven new subclasses, the `Farm` class was generalized into a configurable single-input/single-output converter that all seven (and the original wood→food Farm) share. Bread, potato, and fruit count toward hunger like plain food does; grain, flour, hops, and beer are intermediate/luxury goods that don't feed anyone directly — beer specifically is reserved for the happiness system below. The 7 new resource types aren't individually shown on the HUD yet (only Food/Wood/Stone/Water have rows there) — they're fully functional, just not surfaced in the compact corner panel.

## Planned Next (from `Implement_Next.txt`)

Not yet built. Listed in priority order as currently planned:

- **Happiness system** — each citizen has individual happiness, averaged into settlement-wide happiness. Access to water/food raises it, shortages lower it, food variety raises it further. Sustained low happiness risks a citizen leaving. This will be the game's first mechanic with a *negative* consequence for resource shortfalls — today, running out of any resource just stalls production, nothing worse. This is also what will finally make the Well's water access and beer matter mechanically.
- **Citizen recruitment** — spend food at the Outpost Hall to recruit a new citizen, choosing between 3 candidates with different starting skills. Today's 3 citizens (Aldric, Brenna, Cass) are fixed for the whole game — there's no way to grow the roster.
- **Resource income/minute on the HUD** — a rate readout, not just the current totals the HUD shows today.

## Long-Term Design Vision

From the original design notes (`Outpost Survival Game Ideas`) — not scheduled, but the direction the game is meant to grow toward:

- A large explorable world with multiple possible base sites, not just the single fixed base that exists today.
- Recruiting citizens with varied skills (today's 3 citizens are fixed and functionally identical aside from independently-trained skill levels — citizen recruitment above is the first step toward this).
- Securing off-base resources on the wider map as supplemental income.
- A simulated world economy, and other settlements to befriend or destroy.
- Import/export via armed caravans — trade is deliberately risky given a dangerous world.
- Base defense against random raids/sieges from aggressive wildlife and hostile settlers.
- A specialization-driven skill system spanning both combat and labor, where the max achievable total level deliberately can't cover every skill — forces build choices per citizen.
- Perma-death for citizens, softened by (unspecified-so-far) ways to minimize lethality.
- Grimdark medieval-fantasy tone: mostly grounded combat, with rare, powerful, and unsettling magic — inspired by State of Decay 2, Warcraft 3, Age of Empires 2, Project Zomboid, RuneScape, and Battle Brothers.
