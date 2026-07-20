#!/usr/bin/env python3
"""Diff Outpost_Survival/Game Systems/Balance.md against the actual code values
it claims to describe.

Balance.md's own workflow (see its header) is: the user edits a Value cell,
hands the file back, and the doc is supposed to always reflect the *current
implemented* state after that. In practice code and doc drift - someone edits
a constant directly, or edits the doc and the edit doesn't get carried into
code. This script catches that drift automatically instead of a full manual
read-through of both every time.

Only handles the file's single `` `path` `` / `` `CONST_NAME` `` row shape -
rows describing a whole table (building costs, combat unit stats, damage
multipliers) aren't parsed here and still need a manual read; those are rare
edits and don't fit a one-row-one-constant regex anyway.

Usage: tools/check_balance.py [path/to/Balance.md]
Exit code 0 = every parseable row matches code; 1 = at least one mismatch
(or a row's referenced file/const/line couldn't be found - reported as
UNRESOLVED, not silently skipped, since a stale File:Line is itself a doc bug).
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DOC = REPO_ROOT / "Outpost_Survival" / "Game Systems" / "Balance.md"

# Matches a markdown table row's Value cell and its `file:line` `CONST_NAME`
# cell, e.g.:  | Starting wood | 10.0 | `autoload/game_state.gd` `DEFAULT_...`
ROW_RE = re.compile(
    r"^\|\s*(?P<knob>[^|]+?)\s*\|\s*(?P<value>[^|]+?)\s*\|\s*"
    r"`(?P<file>[a-zA-Z0-9_/\.]+\.gd)(?::(?P<line>\d+))?`\s*`(?P<const>[A-Za-z_][A-Za-z0-9_]*)`"
)

# First numeric token in a Value cell - handles "120.0", "10 brick", "3", "1x / 2x / 4x".
NUM_RE = re.compile(r"-?\d+(?:\.\d+)?")


def extract_doc_number(value_cell: str):
    m = NUM_RE.search(value_cell)
    return float(m.group()) if m else None


def find_const_value(file_path: Path, const_name: str, hint_line: int | None):
    """Find `const NAME := <value>` or `NAME := <value>` in file_path.
    Tries the hinted line first (+/- a small window, since the doc warns
    line numbers can drift), then falls back to a whole-file search."""
    if not file_path.exists():
        return None, None
    lines = file_path.read_text().splitlines()
    # Matches `const NAME := X`, `var NAME := X`, and typed `@export var
    # NAME: float = X` alike - anything binding NAME to a bare numeric
    # literal. Dict/array literals (DEFAULT_RESOURCES, HAPPINESS_BANDS,
    # SPEED_MULTIPLIERS) deliberately don't match this and fall through to
    # UNRESOLVED - multi-value rows need a human to read them anyway.
    assign_re = re.compile(rf"\b{re.escape(const_name)}\b\s*(?::\s*\w+)?\s*:?=\s*(-?\d+(?:\.\d+)?)\b")

    def scan(rng):
        for i in rng:
            if 0 <= i < len(lines) and assign_re.search(lines[i]):
                m = assign_re.search(lines[i])
                return float(m.group(1)), i + 1
        return None, None

    if hint_line:
        window = range(hint_line - 6, hint_line + 5)
        val, ln = scan(window)
        if val is not None:
            return val, ln

    return scan(range(len(lines)))


def main():
    doc_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_DOC
    text = doc_path.read_text()

    mismatches = []
    unresolved = []
    checked = 0

    for line in text.splitlines():
        m = ROW_RE.match(line.strip())
        if not m:
            continue
        knob = m.group("knob")
        doc_value = extract_doc_number(m.group("value"))
        if doc_value is None:
            continue
        rel_file = m.group("file")
        hint_line = int(m.group("line")) if m.group("line") else None
        const_name = m.group("const")

        code_value, found_line = find_const_value(REPO_ROOT / rel_file, const_name, hint_line)
        checked += 1
        if code_value is None:
            unresolved.append(f"  {knob}: `{const_name}` not found in {rel_file} (doc says line {hint_line})")
            continue
        if code_value != doc_value:
            mismatches.append(
                f"  {knob}: doc={doc_value!r} vs code={code_value!r} "
                f"({rel_file}:{found_line} `{const_name}`)"
            )

    print(f"Checked {checked} single-constant rows from {doc_path}")
    if mismatches:
        print(f"\nMISMATCHES ({len(mismatches)}) - doc value not yet applied to code (or vice versa):")
        print("\n".join(mismatches))
    if unresolved:
        print(f"\nUNRESOLVED ({len(unresolved)}) - couldn't locate the referenced const, check by hand:")
        print("\n".join(unresolved))
    if not mismatches and not unresolved:
        print("\nAll parseable rows match code.")

    print(
        "\nNote: table-shaped sections (Building Costs & Output, Combat - Unit "
        "Stats, Combat - Damage Multipliers) aren't parsed by this script - "
        "diff those by hand."
    )
    return 1 if (mismatches or unresolved) else 0


if __name__ == "__main__":
    sys.exit(main())
