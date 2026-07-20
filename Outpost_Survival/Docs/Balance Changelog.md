# Balance Changelog

Before/after values only, batched by timestamp. See [[Balance]] for the current state and file/line locations.

## 2026-07-16

- Starting cabbage: 50.0 → 30.0
- Starting wood: 5.0 → 10.0
- Food per citizen per meal: 18.0 → 10.0
- Cabbage Farm cost: 6 wood → 10 wood
- Lumber Camp cost: 5 wood → 10 wood
- Lumber Camp wood_per_chop: 2.0 → 1.0
- House cost: 10 wood → 20 wood
- House upgrade cost: 15 wood + 10 brick → 20 wood + 10 brick
- Stone Mine cost: 8 wood → 10 wood
- Brickmaker cost: 8 wood + 6 stone → 10 wood + 10 stone
- Brickmaker output: 1.0 brick → 0.5 brick
- Storage Facility cost: 15 wood + 10 stone → 25 wood + 25 stone
- Grain Farm cost: 6 wood → 10 wood
- Mill cost: 8 wood + 6 brick → 10 wood + 10 brick
- Outpost Hall: placeable → not placeable
- Recruit cost per food tier: 15.0 → 20.0
- Recruit starting skill level: 5 → 10
- Recruit level step per food tier: 5 → 10
- Well cost: 4 wood + 10 stone → 5 wood + 10 stone
- Bakery cost: 8 wood + 4 stone → 10 wood + 5 stone
- Hops Farm cost: 6 wood → 10 wood
- Brewery cost: 10 wood + 4 stone + 6 brick → 10 wood + 5 stone + 5 brick
- Fruit Orchard cost: 8 wood → 20 wood
- Fruit Orchard output: 0.6 fruit → 2.0 fruit
- Potato Farm cost: 6 wood → 10 wood
- Barracks cost: 10 wood + 6 stone → 20 wood + 10 stone
- Archery Range cost: 8 wood + 4 stone → 10 wood + 5 stone
- Mage Tower cost: 6 wood + 8 stone + 4 brick → 10 wood + 10 stone + 5 brick
- Lumber Camp wood_per_chop: 1.0 → 2.0
- Lumber Camp chop_interval: 2.4s → 2.0s
- Military building (Barracks/Archery Range/Mage Tower) worker cap: 1 → 3, +3 per upgrade (new, cost 10 brick/upgrade)
- Carry limit (haul size): 6.0 → 8.0
- Max move duration: 8.0s → 2.0s → 20.0s
- Happiness ease rate: 3.0 → 1.0
- Happiness water bonus: 15.0 → 5.0
- Happiness food bonus: 15.0 → 10.0
- Unhappy threshold: 20.0 → 15.0
- Trapper slow duration: 2.0s → 4.0s
- Lumber Camp chop_interval: 2.0s → 3.0s
- Food per citizen per meal: 10.0 → 12.0
- Default work cycle interval: 3.0s → 6.0s
- Fruit Orchard work_interval (scaled to stay 2x the default): 6.0s → 12.0s
- Lumber Camp chop_interval (scaled alongside the default): 3.0s → 6.0s
- Cabbage Farm input: none → 0.5 wood/tick
- Fruit Orchard input: none → 1.0 wood/tick
- Potato Farm input: none → 0.5 wood/tick

## 2026-07-18

Sweeping economy pass - most building costs raised significantly, a few outputs tuned alongside them:
- Starting cabbage: 30.0 → 100.0
- Starting wood: 10.0 → 50.0
- Base storage capacity (per resource): 2000.0 → 1000.0
- Cabbage Farm cost: 10 wood → 25 wood; output: 1.0 → 1.1 cabbage
- Lumber Camp cost: 10 wood → 50 wood
- House cost: 20 wood → 50 wood
- House upgrade cost: 20 wood + 10 brick → 100 wood + 50 brick
- Stone Mine cost: 10 wood → 25 wood; output: 0.5 → 0.6 stone
- Brickmaker cost: 10 wood + 10 stone → 100 wood + 25 stone
- Well cost: 5 wood + 10 stone → 50 wood + 50 stone
- Storage Facility cost: 25 wood + 25 stone → 500 wood + 100 stone; bonus: 1000 → 60 capacity/resource
- Grain Farm cost: 10 wood → 25 wood
- Mill cost: 10 wood + 10 brick → 50 wood + 25 brick
- Bakery cost: 10 wood + 5 stone → 50 wood + 25 brick (resource-type swap, stone → brick)
- Hops Farm cost: 10 wood → 25 wood
- Brewery cost: 10 wood + 5 stone + 5 brick → 25 wood + 15 stone + 15 brick (recipe still single-input hops only - see Balance.md's "Not yet implemented" note, two-input isn't supported by Workshop yet)
- Fruit Orchard cost: 20 wood → 200 wood; output: 2.0 → 2.2 fruit
- Potato Farm cost: 10 wood → 25 wood
- Barracks cost: 20 wood + 10 stone → 100 wood + 25 stone
- Archery Range cost: 10 wood + 5 stone → 125 wood + 25 brick (resource-type swap, stone → brick)
- Mage Tower cost: 10 wood + 10 stone + 5 brick → 200 wood + 25 stone + 25 brick
- Military building upgrade cost: 10 brick → 25 brick
- Labor required per material unit: 1.5 → 1.3
- Sapling grow time: 100.0s → 700.0s
- Recruit cost per food tier: 20.0 → 50.0

Follow-up to the pass above - offsets the much higher building costs so construction time doesn't scale up right alongside them:
- Labor required per material unit: 1.3 → 0.6

## 2026-07-18 (later)

- Labor added per work tick: 1.0 → 2.0
- Carry limit (haul size): 8.0 → 10.0
- Lumber Camp cost: 50 wood → 25 wood (no longer in lockstep with starting wood, which stays at 50 - now leaves 25 wood spare rather than exactly covering it)

## 2026-07-18 (even later)

- Wood per tree: 20.0 → 80.0 (new knob - 40 chops to deplete a tree at the default 2.0 wood/chop, up from 10)

## 2026-07-17

Doc corrections, not new tuning - these three were edited directly in code (outside the usual edit-and-hand-back flow) and/or the doc was simply stale; [[Balance]] reconciled to match actual code rather than code changed to match the doc:
- Base storage capacity: 120.0 → 2000.0 (direct code edit)
- Labor required per material unit: 1.5 → 2.0 (doc was stale)
- Minimum labor required (floor): 5.0 → 10.0 (doc was stale)

Real tuning, not a doc correction this time - construction sped back up:
- Labor required per material unit: 2.0 → 1.5
- Minimum labor required (floor): 10.0 → 5.0

## 2026-07-20

`tools/check_balance.py` flagged the doc had moved ahead of code (doc edited via the usual hand-back workflow, not yet implemented) - implemented into code:
- Labor required per material unit: 0.6 → 0.5
- Minimum labor required (floor): 5.0 → 2.0
- Starving penalty: doc previously showed the net effect (-20.0); corrected to show the actual constant (20.0, negated at its one call site)
