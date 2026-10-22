"""Check that two versions of one edition behave identically.

Plays the same seeded sessions on both and compares every line of output.
Use it after a refactor that must not change the game:

    cp pc/FiniteDungeons.py /tmp/old.py      # before the change
    python3 tools/fuzz_compare.py /tmp/old.py pc/FiniteDungeons.py
    cp -r calc /tmp/calc_old                 # before the change
    python3 tools/fuzz_compare.py /tmp/calc_old calc

A target is the PC file or a calc/ folder (run with tools/casioplot.py).
Two kinds of session, --seeds of each:
  ui      random keys through the whole game: save prompt, menus, library,
          shop, hidden codes, fights. Covers every screen.
  engine  random purchase walks straight through the engine functions, from
          a random relic/artefact, starting wallet (up to 5000) and extra HP
          (up to 20000), so deep levels, the drone, the Coinpot and the
          level-30 boss get exercised. Logs every event
          (raw and rendered) and the player's state after each step.
"""
import argparse
import builtins
import contextlib
import difflib
import hashlib
import importlib.util
import io
import os
import random
import re
import sys
import time
from multiprocessing import Pool

TOOLS = os.path.dirname(os.path.abspath(__file__))
CALC_MODULES = ("fdterm", "fddata", "fdval", "fdtxt1", "fdtxt2", "fdtxt3", "fdtxt4",
                "fdmodel", "fdshop", "fdfight", "fdevent", "fdui", "fdhub", "findun")
SAVES = ["0", "0", "008iH", "005od", "0033l", "002Rz", "00X7s", "zzzzz", "abc"]
SPECIAL = ["235", "777", "888", "999", "505", "", "x", "99"]
# ANSI colour codes (PC) and colour marker characters (calc), for --ignore-colour.
COLOUR_CODES = re.compile("\x1b\\[[0-9;]*m|[\x01-\x07]")


class Stop(BaseException):
    """Ends a session; BaseException so the games' own handlers don't catch it."""


def is_calc(target):
    return os.path.isdir(target)


def ui_key(rng):
    r = rng.random()
    if r < 0.25:
        return "0"
    if r < 0.85:
        return str(rng.randint(1, 11))
    return rng.choice(SPECIAL)


# ---------- ui sessions ----------

def ui_pc(target, seed):
    rng = random.Random(seed)
    limit = rng.choice([150, 400, 1200])
    out = io.StringIO()
    count = [0]

    def fake_input(prompt=""):
        out.write(prompt)
        count[0] += 1
        if count[0] > limit:
            raise Stop
        key = rng.choice(SAVES) if "save code" in prompt else ui_key(rng)
        out.write(key + "\n")
        return key

    builtins.input, real_input = fake_input, builtins.input
    sleep, system = time.sleep, os.system
    time.sleep = lambda s: None
    os.system = lambda cmd: 0
    try:
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            spec = importlib.util.spec_from_file_location("__main__", target)
            mod = importlib.util.module_from_spec(spec)
            try:
                spec.loader.exec_module(mod)
            except Stop:
                pass
    finally:
        builtins.input, time.sleep, os.system = real_input, sleep, system
    return out.getvalue()


def load_calc(target):
    """Fresh import of a calc folder's modules (with fdterm patched first)."""
    for name in CALC_MODULES:
        sys.modules.pop(name, None)
    sys.path[:0] = [os.path.abspath(target), TOOLS]
    try:
        import fdterm
        return fdterm
    finally:
        del sys.path[:2]


def ui_calc(target, seed):
    rng = random.Random(seed)
    limit = rng.choice([150, 400, 1200])
    log = []
    count = [0]
    fdterm = load_calc(target)

    def ask(prompt="> "):
        if "EXE" in prompt:
            log.append("[" + prompt + "]")
            return ""
        count[0] += 1
        if count[0] > limit:
            raise Stop
        key = ui_key(rng)
        key = key if key.isdigit() else ""   # the calculator only types digits
        log.append(prompt + key)
        return key

    def fake_input(prompt=""):
        count[0] += 1
        if count[0] > limit:
            raise Stop
        key = rng.choice(SAVES)
        log.append(prompt + key)
        return key

    fdterm.LOG = log
    fdterm.ask = ask
    fdterm.wait = lambda sec: None
    real_status = fdterm.status
    fdterm.status = lambda text="": (log.append("[status] " + text), real_status(text))
    builtins.input, real_input = fake_input, builtins.input
    real_print = builtins.print
    builtins.print = lambda *a, **k: log.append("[print] " + " ".join(map(str, a)))
    sys.path[:0] = [os.path.abspath(target), TOOLS]
    try:
        import findun  # runs the game
    except Stop:
        pass
    finally:
        del sys.path[:2]
        builtins.input, builtins.print = real_input, real_print
    return "\n".join(log)


# ---------- engine walks ----------

class Engine:
    """The engine functions of one target, under the PC file's names."""

    def __init__(self, target):
        if is_calc(target):
            load_calc(target)
            sys.path[:0] = [os.path.abspath(target), TOOLS]
            try:
                import fdmodel, fdshop, fdfight, fdevent
            finally:
                del sys.path[:2]
            mods = [fdmodel, fdshop, fdfight, fdevent]
            self.calc = True
        else:
            spec = importlib.util.spec_from_file_location("fd_engine", target)
            mod = importlib.util.module_from_spec(spec)
            system, os.system = os.system, (lambda cmd: 0)
            try:
                with contextlib.redirect_stdout(io.StringIO()):
                    spec.loader.exec_module(mod)
            finally:
                os.system = system
            mods = [mod]
            self.calc = False
        for name in ("Player", "create_monster", "try_buy", "activate_socks",
                     "take_water_sample", "switch_relic", "buy_drone_upgrade",
                     "vitality_money_penalty", "coinpot_payout", "fight", "post_fight",
                     "format_event", "unlocked_relics", "unlocked_artefacts"):
            setattr(self, name, next(getattr(m, name) for m in mods if hasattr(m, name)))

    def totals(self, p):
        if self.calc:
            return p.total_atk(), p.total_df(), p.total_spd()
        return p.total_atk, p.total_df, p.total_spd


RELICS = [None, "family", "blessed", "forbidden", "e-sword", "bk", "sk", "yd", "gk",
          "meowton", "dk"]
ARTEFACTS = [None, "devotion", "socks", "ar", "coinpot", "carrier", "vitality"]
ITEMS = ["sword", "shield", "boots", "chicken", "battery", "ink", "elixir",
         "book_atk", "book_def", "book_spd", "book_hp", "book_heal"]


def state(e, p):
    d = p.drone
    return repr((p.hp, p.max_hp, p.atk, p.df, p.spd, p.extra_atk, p.extra_df, p.extra_spd,
                 e.totals(p), p.money, p.relic, p.switches, p.revive_used,
                 p.forbidden_ink, p.forbidden_ink_total, p.counters, sorted(p.books.items()),
                 sorted(p.bought.items()), p.socks_sealed, p.pending_hp_multiplier,
                 p.ar_used, p.elixir_timers, d.atk, d.stages, d.slots_used, p.coinpot_bonus))


def engine_walk(e, seed):
    rng = random.Random(seed)
    lines = []
    ac = {}

    def log(events):
        for ev in events:
            lines.append(repr(sorted(ev.items())))
            lines.extend(e.format_event(ev))

    artefact = rng.choice(ARTEFACTS)
    relic = rng.sample(RELICS[1:], 3) if artefact == "carrier" else rng.choice(RELICS)
    p = e.Player(relic, artefact)
    p.money = rng.choice([0, 0, 0, 20, 200, 5000])
    boost = rng.choice([0, 0, 100, 1000, 20000])   # extra HP so walks reach level 30
    p.max_hp += boost
    p.hp += boost
    lines.append("start %r %r %r %r" % (relic, artefact, p.money, boost))
    for level in range(1, 31):
        p.bought_elixir_this_visit = 0
        for _ in range(rng.randint(0, 16)):
            act = rng.random()
            dead = False
            if act < 0.6:
                events, dead = e.try_buy(p, rng.choice(ITEMS), ac)
            elif act < 0.8:
                events = e.buy_drone_upgrade(p, rng.randint(0, 3))
            elif act < 0.87:
                events, dead = e.take_water_sample(p, level, ac)
            elif act < 0.94:
                events = e.activate_socks(p)
            elif artefact == "carrier":
                events = e.switch_relic(p)
            else:
                events = []
            log(events)
            lines.append(state(e, p))
            if dead:
                return lines
        if p.artefact == "coinpot" and p.money >= 3:
            p.coinpot_bonus += (p.money // 3) * 2
        if p.artefact == "vitality":
            p.vitality_drain_pending = True
        log(e.vitality_money_penalty(p))
        log(e.coinpot_payout(p))
        won, events = e.fight(p, e.create_monster(level), level, ac)
        log(events)
        lines.append(state(e, p))
        if not won:
            break
        log(e.post_fight(p, level))
        lines.append(state(e, p))
    lines.append(repr(sorted(ac.items())))
    for h in (0, 3, 8, 12, 18, 20, 30, 999999):
        lines.append(repr((e.unlocked_relics(h), e.unlocked_artefacts(h))))
    return lines


# ---------- driver ----------

def session(kind, target, seed, ignore_colour=False):
    if kind == "ui":
        text = ui_calc(target, seed) if is_calc(target) else ui_pc(target, seed)
    else:
        text = "\n".join(engine_walk(Engine(target), seed))
    return COLOUR_CODES.sub("", text) if ignore_colour else text


def job(args):
    kind, target, seeds, ignore_colour = args
    return [(kind, s, hashlib.sha256(session(kind, target, s, ignore_colour).encode()).hexdigest())
            for s in seeds]


def run(target, seeds, workers, ignore_colour=False):
    chunks = [(kind, target, list(range(i, min(i + 50, seeds))), ignore_colour)
              for kind in ("ui", "engine") for i in range(0, seeds, 50)]
    with Pool(workers) as pool:
        return {(k, s): h for part in pool.map(job, chunks) for k, s, h in part}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("old")
    ap.add_argument("new")
    ap.add_argument("--seeds", type=int, default=1000, help="sessions of each kind (default 1000)")
    ap.add_argument("--workers", type=int, default=os.cpu_count())
    ap.add_argument("--ignore-colour", action="store_true",
                    help="strip colour codes first (checks that only colours changed)")
    a = ap.parse_args()
    if is_calc(a.old) != is_calc(a.new):
        ap.error("compare a PC file with a PC file, or a calc folder with a calc folder")

    start = time.time()
    old = run(a.old, a.seeds, a.workers, a.ignore_colour)
    new = run(a.new, a.seeds, a.workers, a.ignore_colour)
    bad = sorted(k for k in old if old[k] != new[k])
    print("%d sessions each, %.0fs: %d differ" % (len(old), time.time() - start, len(bad)))
    for kind, seed in bad[:3]:
        print("\n--- %s seed %d ---" % (kind, seed))
        o = session(kind, a.old, seed, a.ignore_colour).splitlines()
        n = session(kind, a.new, seed, a.ignore_colour).splitlines()
        diff = list(difflib.unified_diff(o, n, "old", "new", n=2, lineterm=""))
        print("\n".join(diff[:40]))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
