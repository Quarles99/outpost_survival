# Outpost Survival — Design Vault

This vault is this project's whole knowledge base: authoritative docs, journal, idea-linking, and in-flight planning all live here.

## Structure

- [[README]] (`Docs/`) — the authoritative gameplay/mechanics/roadmap reference (moved here from a root-level `docs/` folder on 2026-07-15). Player/design-facing, kept separate from `CLAUDE.md` (engine/architecture guidance to Claude).
- `Journal/` — dated session notes (`Journal/YYYY-MM-DD.md`): what was discussed or decided, why, open questions
- [[Ideas]] (`Actionable Ideas/`, renamed from `Ideas/`) — one note per design idea/concept, linked to related ideas and to the journal entries where they came up; doubles as the implementation backlog (see `CLAUDE.md`). Finished ideas move to `Actionable Ideas/Completed/`.
- `Game Systems/` — detailed, changelog-tracked design/technical docs for major systems (combat, balance, day/night, formation AI) that are denser than `Docs/`'s player-facing prose warrants. [[Balance]] lives here: a condensed, edit-and-hand-back reference table of every numeric balance knob in the game, with exact file/line locations — not a replacement for `Docs/stats.md`'s prose, purpose-built for the user to tweak values directly and hand them back for implementation. [[Balance Changelog]] (`Docs/`) tracks the history of edits made through it; `Balance.md` itself only ever shows the current state.
- `Art/` — reference images used while building sprites/UI.

Link freely with `[[wikilinks]]` as ideas connect to each other and to the journal entries that spawned them.
