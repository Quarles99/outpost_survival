# Outpost Survival — Documentation

Player/design-facing documentation for the game, kept in sync with the implementation as it's built. If you want engine/architecture details (which script owns what, why something was built a certain way), see `/CLAUDE.md` instead — these docs describe *what the game does*, not *how the code does it*.

- **[mechanics.md](Outpost_Survival/Docs/mechanics.md)** — how each system works: resources, population, gathering & hauling, skills & leveling, building & placement, the world grid, trees, saving.
- **[stats.md](Outpost_Survival/Docs/stats.md)** — every concrete number in the game (costs, rates, timers, curves) in one reference.
- **[controls.md](Outpost_Survival/Docs/controls.md)** — every input and what it does.
- **[roadmap.md](Outpost_Survival/Docs/roadmap.md)** — what's implemented vs. planned, and the long-term design vision.

## What the game is right now

A single-base isometric (2:1 dimetric) survival/builder. Citizens (3 to start, growing via recruitment) automatically staff Farm-family, Lumber Camp, Stone Mine, and Brickmaker posts around a starting Outpost Hall, which also serves as the stockpile — Houses raise population capacity, Wells grant water access, Storage Facilities raise stockpile capacity. There's no combat, no world map, and no enemies yet — just the economic loop of gathering, hauling, consumption, happiness, and per-citizen skill growth. See [roadmap.md](Outpost_Survival/Docs/roadmap.md) for what's coming next.

## Keeping this up to date

This documentation is maintained alongside development: a fresh pass happens whenever an item in the `Actionable Ideas/` backlog (see `Home.md`) is implemented, so `mechanics.md` and `stats.md` should always describe the current build, not a stale one.
