# Roadmap

Tracks what's implemented vs. what's planned. Source of truth for "what's next" is `/Implement_Next.txt` at the repo root — this page restates it in plain language and folds in the longer-term vision from `/Outpost Survival Game Ideas`. Updated whenever an item there is marked `[DONE]`.

## Implemented

**Save & load.** Local save/load (see [controls.md](controls.md) for `F5`/`F9`) covering resources, population, water access, storage capacity, every tree, every player-placed building, workstation buffers, and each citizen's skill progress and current job. One fixed local slot, no menu yet. Cloud sync is a stated future goal, not started.

**Realistic travel & labor.** Gathering is no longer instant/passive — citizens physically walk to workstations and haul goods to and from the stockpile (the Outpost Hall), with buffered output/input and per-post carry limits. Movement and work speed were deliberately slowed to read as "slow but consistent" rather than twitchy. Trees are a shared, sustainably-managed resource (Lumber Camps replant toward an area-wide target) rather than a one-time deposit. Idle citizens double as general haulers, picking whichever job (an output pickup or an input delivery) moves the most material across every workstation, with overshoot protection when multiple haulers converge on the same starved post. See [mechanics.md](mechanics.md#gathering--hauling) for the full loop.

**Water resource.** A Well (built from stone + wood) grants unlimited water access rather than a depletable stockpile — the game just tracks whether water is available, not an amount. Not consumed by anything yet; the planned Happiness system below is what will eventually care whether a settlement has water.

**Stone resource.** A Stone Mine produces stone with no input requirement, using the same generic produce-and-haul loop as any simple gatherer. Nothing costs stone except the Well and Storage Facility yet — a proper stone-consuming building lineup (walls, upgrades) is still to come.

**Storage facility.** Resources are now capped (they weren't before) — each resource type independently caps at a shared "storage capacity" value, 30 by default even with no facilities built. A Storage Facility adds +30 more, and multiple can be built for cumulative capacity. Overflow past capacity is lost rather than refunded, which is an intentional consequence of the cap existing, not a bug. Not yet upgradeable in place (build another facility instead) — that needs a building-selection interaction that doesn't exist for passive structures yet.

**Alternative crop types.** The full grain→flour→bread and hops→beer refinement chains, plus fruit and potato as simple no-input crops, are all buildable now (Grain Farm, Mill, Bakery, Hops Farm, Brewery, Fruit Orchard, Potato Farm — see [stats.md](stats.md#workstation-production) for the full chain). Rather than seven new subclasses, the `Farm` class was generalized into a configurable single-input/single-output converter that all seven (and the original wood→food Farm) share. Bread, potato, and fruit count toward hunger like plain food does; grain, flour, hops, and beer are intermediate/luxury goods that don't feed anyone directly — beer specifically is reserved for the happiness system below. The 7 new resource types aren't individually shown on the HUD yet (only Food/Wood/Stone/Water have rows there) — they're fully functional, just not surfaced in the compact corner panel.

**Happiness system.** Each citizen has individual happiness (0–100) that eases toward a target recomputed from water access, food stock, and food variety, rather than jumping instantly. Settlement happiness (shown on the HUD) is the average across all citizens. A citizen whose happiness stays below threshold for a sustained stretch leaves the settlement for good — the game's first mechanic where a resource shortfall costs more than stalled production. This is what finally makes the Well's water access and food variety matter mechanically. See [mechanics.md](mechanics.md#happiness).

**Citizen recruitment.** Clicking the Outpost Hall offers 3 candidates, each with a different randomly-chosen specialization pre-trained to a head-start level; recruiting spends food and requires an open House slot. The starting 3 citizens (Aldric, Brenna, Cass) are no longer the whole game's roster — the town can now grow. See [mechanics.md](mechanics.md#citizen-recruitment).

**Resource income/minute.** The HUD's Food/Wood/Stone rows now show a rolling net income-per-minute rate alongside the current amount, computed from a trailing 60-second window of resource-pool snapshots so bursty haul-trip deposits read as a steady rate.

**Condensed build menu.** The build menu is now a grid of square icon buttons (real per-building texture + tint) with small keybind numbers, instead of a vertical list of full-width text buttons — hover an icon for its full name and cost.

**Larger map.** The playable grid is now 28×28 tiles (784 total), 4x the original 14×14 — a pure data change, since bounds/camera limits were already computed dynamically from the ground's size.

**Speed and strength skills.** Two universal skills every citizen trains passively regardless of assignment — speed from moving, strength from completing haul trips. Speed multiplies movement speed; strength multiplies how much a citizen can carry per trip beyond a workstation's base carry limit. Not surfaced in any UI yet — that's what the planned per-citizen skill panel below is for. See [mechanics.md](mechanics.md#skills--leveling).

**Happiness bonuses/debuffs.** Settlement happiness now falls into one of four named bands (Thriving/Content/Unhappy/Miserable, shown on the HUD) each applying a flat production multiplier (1.15x down to 0.6x) on top of every worker's own skill multiplier — the game's first happiness effect beyond "leave if sustained low." See [mechanics.md](mechanics.md#happiness).

## Planned Next (from `Implement_Next.txt`)

Not yet built. Listed in priority order as currently planned:

- **Per-farm crop selection** — choose what a Farm-family building grows/converts by clicking it, instead of the crop being fixed at build time by which catalog entry was placed.
- **Per-workstation worker cap** — a maximum number of citizens assignable to a single post (today's "multiple workers share one post's buffers" is uncapped).
- **Remove the click-to-open task list** — assignment becomes drag-only, or click-citizen-then-click-workstation, instead of today's menu-of-posts panel.
- **Per-citizen skill panel** — a condensed view of all of a citizen's skill levels, opened by clicking them (today only the task-assignment menu opens on click).

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
