#!/usr/bin/env python3
"""Generate tests/parity/fuzz.json: seeded random runs for the parity harness.

Each run is played through the Python spec while it is generated, so only actions the
Python UI would offer at that moment are chosen (shop rows from shop_menu(), drone tracks
with the RAY-24, 235/777/888 with their artefacts). Some runs get money injections so they
reach late levels and the level-30 win.

Usage: python3 -I tests/parity/gen_fuzz.py [COUNT] [SEED]   (defaults 300, 1224)
Re-run and commit the JSON whenever the op vocabulary changes.
"""
import importlib.util
import json
import os
import random
import sys

sys.dont_write_bytecode = True   # no __pycache__ next to the spec / harness

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("parity", os.path.join(HERE, "parity.py"))
parity = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(parity)
fd = parity.fd

RELICS = [k for k, _ in fd.RELIC_UNLOCKS]
ARTEFACTS = [""] + [k for k, _ in fd.ARTEFACT_UNLOCKS]


def _code(runs, highest):
    prof = fd.Profile()
    prof.runs, prof.highest = runs, highest
    return fd.save_code(prof)


# (runs, highest) starting profiles: fresh players (the "few runs" win is possible) and veterans.
START_CODES = [_code(0, 0), _code(0, 0), _code(1, 7), _code(2, 30), _code(12, 30)]


def reachable(r):
    """Every action the Python shop would accept right now."""
    _, options = parity.capture(fd.shop_menu, r.player, r.level)
    ops = [["buy", item] for item in options.values() if item != "yds"]
    p = r.player
    if p.relic == "yd":
        ops += [["drone", t] for t in range(4)]
    if p.artefact == "ar":
        ops.append(["water"])
    if p.artefact == "socks":
        ops.append(["socks"])
    if p.artefact == "carrier":
        ops.append(["switch"])
    return ops


def gen_run(rng, idx):
    artefact = rng.choice(ARTEFACTS)
    relic = rng.sample(RELICS, fd.CARRIER_RELICS) if artefact == "carrier" else rng.choice([""] + RELICS)
    boost = rng.choice([0, 0, 0, 5, 20, 80, 400, 3000])
    greedy = rng.random() < 0.5
    scenario = {"name": f"fuzz{idx:03d}", "code": rng.choice(START_CODES), "display": "level", "ops": []}
    r = parity.Run(scenario["code"])

    def do(op):
        scenario["ops"].append(op)
        parity.apply_op(r, op)

    do(["start", artefact, relic])
    if rng.random() < 0.25:  # start deeper, for late-level effects and the level-30 win
        do(["setlevel", rng.randint(2, fd.FINAL_LEVEL)])
        do(["addmoney", rng.choice([50, 500, 5000])])
    while not r.over:
        do(["level"])
        if boost and rng.random() < 0.6:
            do(["addmoney", boost])
        for _ in range(rng.randint(0, 10 if greedy else 4)):
            if r.over:
                break
            choices = reachable(r)
            if greedy:
                # prefer things that are still in stock
                stocked = [c for c in choices if not (c[0] == "buy" and c[1] in ("sword", "shield", "boots")
                                                     and r.player.bought[c[1]] >= fd.LIMIT[c[1]])]
                choices = stocked or choices
            do(rng.choice(choices))
        if r.over:
            break
        do(["quit"] if rng.random() < 0.01 else ["fight"])
    return scenario


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1224
    rng = random.Random(seed)
    runs = [gen_run(rng, i) for i in range(count)]
    with open(os.path.join(HERE, "fuzz.json"), "w", encoding="utf-8") as f:
        json.dump(runs, f, separators=(",", ":"))
        f.write("\n")
    levels = [sum(1 for op in s["ops"] if op[0] == "fight") for s in runs]
    print(f"{count} runs, {sum(len(s['ops']) for s in runs)} ops, max level {max(levels)}, "
          f"runs reaching 30: {sum(1 for n in levels if n >= 30)}")


if __name__ == "__main__":
    main()
