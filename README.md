# Outpost Survival

A grimdark medieval-fantasy base-building/survival game, built in Godot 4.7. Recruit citizens, staff gathering and crafting posts, and grow a single outpost from three settlers and an empty map into a self-sufficient (and eventually defended) town.

Inspired by *State of Decay 2*, *Warcraft 3*, *Age of Empires 2*, *Project Zomboid*, *RuneScape*, and *Battle Brothers*.

## What's playable right now

- **Automatic job assignment.** No manual worker management — citizens propose to the post matching their best skill (Gale-Shapley matching under the hood), displacing weaker incumbents as they level up. Anyone without a post hauls resources instead.
- **A real production economy.** Lumber camps that sustainably replant trees, a stone mine and mineable rocks, and full crop chains (grain→flour→bread, hops→beer, plus fruit/potato/cabbage) — all built, walked to, and worked by citizens in real time rather than instant/idle.
- **Population, water, and storage.** Houses raise population capacity, Wells grant water access (which also boosts farm output), Storage Facilities raise the stockpile cap.
- **Skills and happiness.** Every citizen levels up per-skill through use, earns titles from Apprentice to Legendary, and has happiness that drifts toward a target based on food/water/variety — sustained misery can cost you the citizen.
- **Day/night cycle** with twice-daily meal consumption, and a fast-forward speed toggle.
- **Early combat.** Barracks/Archery Range/Mage Tower train soldiers; small orc raiding parties spawn at night and can be met head-on by rallying your trained citizens onto the town map.
- **Building & construction.** Place a building, haul its materials, then have a worker complete construction labor before it goes live — plus a demolish mode that refunds materials and salvages trees/rocks instead of just deleting them.
- **Save/load**, pathfinding around buildings and other citizens, and a live HUD showing resource rates.

See [roadmap.md](Outpost_Survival/Docs/roadmap.md) for the full implemented list and the longer-term design vision (a wider explorable world, varied citizen skills, trade caravans, perma-death, and more).

## Running the project

This is a [Godot 4.7](https://godotengine.org/) project (GDScript, `gl_compatibility` renderer) — there's no separate build step. Open the project folder in the Godot 4.7 editor and run it, or from the command line:

```sh
godot4 --path .
```

The main scene is `res://scenes/base/Base.tscn`.

## Documentation

Player-facing docs live in [`Outpost_Survival/Docs/`](Outpost_Survival/Docs/):

- **[mechanics.md](Outpost_Survival/Docs/mechanics.md)** — how each system works: resources, population, gathering & hauling, skills & leveling, building & placement, the world grid, trees, saving.
- **[stats.md](Outpost_Survival/Docs/stats.md)** — every concrete number in the game (costs, rates, timers, curves) in one reference.
- **[controls.md](Outpost_Survival/Docs/controls.md)** — every input and what it does.
- **[roadmap.md](Outpost_Survival/Docs/roadmap.md)** — what's implemented vs. planned, and the long-term design vision.

Deeper technical/architecture notes (which script owns what, why something was built a certain way) live in [`CLAUDE.md`](CLAUDE.md). The full `Outpost_Survival/` folder is an Obsidian vault used as this project's working knowledge base, including per-system design docs under `Game Systems/` and the active idea backlog under `Actionable Ideas/`.
