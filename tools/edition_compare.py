"""Check that the PC edition and the calculator edition play the same game.

Plays fuzz_compare.py's seeded engine walks (random purchases, drone upgrades
and artefact actions from a random relic/artefact, wallet and HP boost,
through to level 30) on pc/FiniteDungeons.py and on calc/, and compares them.
Every event and every player-state snapshot must be equal, and every line of
event text must be equal once the PC's non-ASCII characters are swapped for
the calculator's spellings (ASCII below). Use it after porting a change from
the PC to calc/:

    python3 tools/edition_compare.py
    python3 tools/edition_compare.py --seeds 3000

Exits 1 and prints the first differences if any walk differs. Menus and the
run() loop are not covered (fuzz_compare.py checks each edition against
itself only), so read those side by side. Nor is MicroPython: CPython
accepts code the fx-CG100 does not.
"""
import argparse
import os
import sys

from fuzz_compare import Engine, engine_walk

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# How calc/ spells the PC's non-ASCII characters.
ASCII = {"—": "-", "’": "'", "→": "->", "∞": "inf",
         "²": "^2", "³": "^3", "⁴": "^4", "雑魚": "Zako"}


def asciify(text):
    for char, spelling in ASCII.items():
        text = text.replace(char, spelling)
    return text


def tagged(engine):
    """Mark event text lines with "T " so they can be told from events and state."""
    real = engine.format_event
    engine.format_event = lambda ev: ["T " + line for line in real(ev)]
    return engine


def first_difference(a, b):
    for i, (x, y) in enumerate(zip(a, b)):
        if x != y:
            return "line %d\n  pc:   %s\n  calc: %s" % (i, x[:300], y[:300])
    return "pc has %d lines, calc %d" % (len(a), len(b))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--pc", default=os.path.join(ROOT, "pc", "FiniteDungeons.py"))
    ap.add_argument("--calc", default=os.path.join(ROOT, "calc"))
    ap.add_argument("--seeds", type=int, default=1000, help="engine walks (default 1000)")
    a = ap.parse_args()

    pc, calc = tagged(Engine(a.pc)), tagged(Engine(a.calc))
    bad_state, bad_text = [], []
    for seed in range(a.seeds):
        p, c = engine_walk(pc, seed), engine_walk(calc, seed)
        p_state = [x for x in p if not x.startswith("T ")]
        c_state = [x for x in c if not x.startswith("T ")]
        if p_state != c_state:
            bad_state.append((seed, first_difference(p_state, c_state)))
        p_text = [asciify(x) for x in p if x.startswith("T ")]
        c_text = [x for x in c if x.startswith("T ")]
        if p_text != c_text:
            bad_text.append((seed, first_difference(p_text, c_text)))

    print("%d engine walks: events/state differ in %d, event text in %d"
          % (a.seeds, len(bad_state), len(bad_text)))
    for kind, bad in (("events/state", bad_state), ("event text", bad_text)):
        for seed, diff in bad[:3]:
            print("\n--- %s, seed %d: %s" % (kind, seed, diff))
    sys.exit(1 if bad_state or bad_text else 0)


if __name__ == "__main__":
    main()
