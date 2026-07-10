# Outpost Survival — Documentation

Player/design-facing documentation for the game, kept in sync with the implementation as it's built. If you want engine/architecture details (which script owns what, why something was built a certain way), see `/CLAUDE.md` instead — these docs describe *what the game does*, not *how the code does it*.

- **[mechanics.md](mechanics.md)** — how each system works: resources, population, gathering & hauling, skills & leveling, building & placement, the world grid, trees, saving.
- **[stats.md](stats.md)** — every concrete number in the game (costs, rates, timers, curves) in one reference.
- **[controls.md](controls.md)** — every input and what it does.
- **[roadmap.md](roadmap.md)** — what's implemented vs. planned, and the long-term design vision.

## What the game is right now

A single-base isometric (2:1 dimetric) survival/builder. Three fixed citizens (Aldric, Brenna, Cass) can be assigned to gather wood (Lumber Camp), mine stone (Stone Mine), or grow food (Farm, which consumes wood), housed around a starting Outpost Hall that also serves as the stockpile — with Houses for population capacity, Wells for water access, and Storage Facilities for stockpile capacity. There's no combat, no world map, no recruitment, and no enemies yet — just the economic loop of gathering, hauling, consumption, and slow per-character skill growth. See [roadmap.md](roadmap.md) for what's coming next.

## Keeping this up to date

This documentation is maintained alongside development: a fresh pass happens whenever an item in `/Implement_Next.txt` is marked `[DONE]`, so `mechanics.md` and `stats.md` should always describe the current build, not a stale one.
