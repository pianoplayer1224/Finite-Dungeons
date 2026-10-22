"""Find how far a run can get, by searching every shop purchase sequence.

Drives the real engine in "pc/FiniteDungeons.py" (try_buy, fight, post_fight...),
so it follows the game's rules exactly and needs no update after a balance change.

    python3 tools/route_search.py blessed devotion       # best level, then guide rows
    python3 tools/route_search.py family none --rows 4   # rows for the first 4 levels only
    python3 tools/route_search.py --highest 12           # every relic/artefact unlocked at 12
                                                         #   (--workers N at once, default 4)
    python3 tools/route_search.py family,blessed,yd carrier --frontier 50   # Carrier: slow

Relic/artefact names are the game's keys ("family", "yd", "ar", ... or "none").

How it searches: level by level, every shop visit is tried, then the fight.
Within one visit purchases are bought in a fixed order (ORDER below), e.g. the
Sword before Attack books, which is never worse. States with the same
purchases are pruned when another is at least as good in every stat
(Pareto). If a level still has more than --frontier states, trim() keeps the
best by score() from each purchase history in turn, so a result is a strong
lower bound, not a proof.
"""
import argparse
import contextlib
import importlib.util
import io
import os
import sys
from multiprocessing import Pool

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_engine():
    spec = importlib.util.spec_from_file_location("fd", os.path.join(ROOT, "pc", "FiniteDungeons.py"))
    mod = importlib.util.module_from_spec(spec)
    system = os.system
    os.system = lambda cmd: 0  # skip the Windows-only "color F0" call
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            spec.loader.exec_module(mod)
    finally:
        os.system = system
    return mod


fd = load_engine()


# ---------- player state ----------

def clone(p):
    q = fd.Player.__new__(fd.Player)
    d = dict(p.__dict__)
    d["books"] = dict(p.books)
    d["bought"] = dict(p.bought)
    d["elixir_timers"] = list(p.elixir_timers)
    if p.relics is not None:
        d["relics"] = list(p.relics)
    drone = fd.Drone()
    drone.atk = p.drone.atk
    drone.stages = list(p.drone.stages)
    drone.slots_used = p.drone.slots_used
    d["drone"] = drone
    q.__dict__.update(d)
    return q


def new_player(relic, artefact):
    """Mirror of the start-of-run effects in run()."""
    p = fd.Player(relic, artefact)
    if p.relic == "e-sword":
        p.atk += fd.ESWORD_ATK
    if artefact == "vitality":
        p.max_hp = fd.VITALITY_HP
        p.hp = fd.VITALITY_HP
    if p.relic == "meowton":
        p.df -= fd.MEOWTON_DEF_LOSS
    if (("blessed" in p.relics) if p.relics else (p.relic == "blessed")):
        p.hp -= fd.BLESSED_START_HP_LOSS
    return p


# ---------- shop ----------

# Purchase order within one visit (hidden codes first: 235 pays money, 777
# must come before Attack books). Drone upgrades may come in any track order.
ORDER = ["235", "777", "888", "drone", "sword", "battery", "shield", "boots",
         "book_atk", "book_def", "book_spd", "book_hp", "elixir", "ink",
         "chicken", "book_heal"]
RANK = {k: i for i, k in enumerate(ORDER)}
ONCE_PER_VISIT = {"235", "777", "888", "sword", "shield", "boots"}
SUCCESS = {"purchased", "water_sample", "socks_activated", "relic_switched", "drone_upgraded"}

NAMES = {"sword": "Sword", "battery": "Battery", "shield": "Shield", "boots": "Boots",
         "chicken": "Chicken", "book_atk": "Book of Attack", "book_def": "Book of Defence",
         "book_spd": "Book of Speed", "book_hp": "Book of Max HP",
         "book_heal": "Book of Healing", "elixir": "Elixir", "ink": "Forbidden Ink",
         "235": "Water sample (235)", "777": "Cursed Socks (777)", "888": "Switch relic (888)"}


def shop_numbers(p):
    """Item -> menu number, built the same way as shop()."""
    nums = {}
    i = 1
    if p.relic == "yd":
        nums["drone"] = i
    elif p.relic != "e-sword" and not p.used_e_sword_before:
        nums["sword"] = i
    else:
        nums["battery"] = i
    i += 1
    nums["shield"] = i
    i += 1
    if p.artefact != "socks":
        nums["boots"] = i
    i += 1
    for item in ("chicken", "book_atk", "book_def", "book_spd", "book_hp", "book_heal"):
        nums[item] = i
        i += 1
    if p.artefact == "devotion":
        nums["elixir"] = i
        i += 1
    if p.relic == "forbidden":
        nums["ink"] = i
    for code in ("235", "777", "888"):
        nums[code] = int(code)
    return nums


def offered(p):
    """Purchases the shop menu offers right now (the engine checks the rest)."""
    items = [k for k in shop_numbers(p) if k not in ("235", "777", "888")]
    if p.artefact == "ar" and not p.ar_used:
        items.append("235")
    if p.artefact == "socks" and not p.socks_sealed and p.hp <= fd.SOCKS_MAX_HP:
        items.append("777")
    if p.artefact == "carrier" and p.switches < fd.CARRIER_RELICS - 1:
        items.append("888")
    return items


def apply(p, item, level, track=None):
    """Do one purchase on p in place. Returns (succeeded, died_in_shop)."""
    ac = {}
    dead = False
    if item == "235":
        ev, dead = fd.take_water_sample(p, level, ac)
    elif item == "777":
        ev = fd.activate_socks(p)
    elif item == "888":
        ev = fd.switch_relic(p)
    elif item == "drone":
        ev = fd.buy_drone_upgrade(p, track)
    else:
        ev, dead = fd.try_buy(p, item, ac)
    return any(e["type"] in SUCCESS for e in ev), dead


def visits(p, level, max_buys):
    """Every canonical shop visit: list of (actions, player after)."""
    out = []

    def rec(q, acts, last):
        out.append((acts, q))
        if len(acts) >= max_buys:
            return
        for item in offered(q):
            r = RANK[item]
            if r < last or (r == last and item in ONCE_PER_VISIT):
                continue
            for track in (range(4) if item == "drone" else [None]):
                q2 = clone(q)
                ok, dead = apply(q2, item, level, track)
                if ok and not dead:
                    rec(q2, acts + [(item, track)], r)

    rec(p, [], -1)
    return out


def leave_and_fight(p, level):
    """Leave the shop and fight, as shop()'s "0" and run() do. None if you die."""
    q = clone(p)
    if q.artefact == "coinpot" and q.money >= fd.COINPOT_STEP:
        q.coinpot_bonus += (q.money // fd.COINPOT_STEP) * fd.COINPOT_PAY
    if q.artefact == "vitality":
        q.vitality_drain_pending = True
    fd.vitality_money_penalty(q)
    fd.coinpot_payout(q)
    won, _ = fd.fight(q, fd.create_monster(level), level, {})
    if not won:
        return None
    fd.post_fight(q, level)
    return q


# ---------- search ----------

def key(p):
    return (p.relic, p.switches, p.revive_used, p.forbidden_ink, p.forbidden_ink_total,
            p.counters, tuple(sorted(p.books.items())), tuple(sorted(p.bought.items())),
            p.socks_sealed, p.pending_hp_multiplier, p.ar_used, tuple(p.elixir_timers),
            tuple(p.drone.stages), p.drone.slots_used, p.used_e_sword_before,
            # Vitality drains HP = money / 2 before each fight, so more money is
            # not always better: only states with the same money compete.
            round(p.money, 2) if p.artefact == "vitality" else None)


def vec(p):
    money = 0 if p.artefact == "vitality" else p.money
    return (p.hp, p.max_hp, p.atk, p.df, p.spd, money, p.extra_atk, p.extra_df, p.extra_spd)


def score(p):
    money = -p.money if p.artefact == "vitality" else p.money
    return (p.hp + p.max_hp * 0.5 + (p.atk + p.extra_atk) * 3 + (p.df + p.extra_df) * 3
            + (p.spd + p.extra_spd) * 2 + money * 0.5)


def pareto(states):
    groups = {}
    for s in states:
        groups.setdefault(key(s[0]), []).append(s)
    out = []
    for group in groups.values():
        group.sort(key=lambda s: vec(s[0]), reverse=True)
        kept = []
        for s in group:
            v = vec(s[0])
            if not any(all(a >= b for a, b in zip(vec(k[0]), v)) for k in kept):
                kept.append(s)
        out += kept
    return out


def trim(states, cap):
    """Keep cap states, taking turns between purchase histories (best score
    first in each). A plain top-score cut drops lines that save books for
    later, e.g. Max HP books held until just before a Blessed heal."""
    groups = {}
    for s in states:
        p = s[0]
        groups.setdefault((tuple(sorted(p.books.items())), tuple(sorted(p.bought.items()))), []).append(s)
    ranked = []
    for group in groups.values():
        group.sort(key=lambda s: score(s[0]), reverse=True)
        ranked += [(i, -score(s[0]), s) for i, s in enumerate(group)]
    ranked.sort(key=lambda r: r[:2])
    return [r[2] for r in ranked[:cap]]


def search(relic, artefact, frontier_cap=20000, max_buys=12):
    """Return (levels beaten, path), path = one list of actions per beaten level."""
    frontier = [(new_player(relic, artefact), ())]
    best = (0, ())
    for level in range(1, fd.FINAL_LEVEL + 1):
        nxt = []
        for p, path in frontier:
            p0 = clone(p)
            p0.bought_elixir_this_visit = 0
            for acts, q in visits(p0, level, max_buys):
                r = leave_and_fight(q, level)
                if r is not None:
                    nxt.append((r, path + (tuple(acts),)))
        if not nxt:
            break
        nxt = pareto(nxt)
        if len(nxt) > frontier_cap:
            nxt = trim(nxt, frontier_cap)
        frontier = nxt
        best = (level, frontier[0][1])
    return best


# ---------- output ----------

def col(text, width):
    return text.ljust(width) if len(text) < width else text + " "


def guide_rows(relic, artefact, path):
    """Rows in strats/win_actions.txt's format; adds the dying level if any."""
    rows = []
    p = new_player(relic, artefact)
    for level, acts in enumerate(list(path) + [()], 1):
        if level > fd.FINAL_LEVEL:
            break
        have = "HP %d/%d $%.2f" % (p.hp, p.max_hp, p.money)
        groups = []
        keys = []
        in_drone_menu = False
        p.bought_elixir_this_visit = 0
        for item, track in acts:
            # Read the numbers before each purchase: Carrier's 888 renumbers
            # the shop (the Drone's slot 1 becomes the Sword, Ink appears).
            nums = shop_numbers(p)
            ok, dead = apply(p, item, level, track)
            assert ok and not dead, (level, item)
            name = NAMES.get(item) or "Drone track %d" % (track + 1)
            if groups and groups[-1][0] == name:
                groups[-1][1] += 1
            else:
                groups.append([name, 1])
            if item == "drone":
                # One trip into the drone menu covers consecutive upgrades.
                if keys[-1:] == ["0"] and in_drone_menu:
                    keys.pop()
                else:
                    keys.append(str(nums[item]))
                keys += [str(track + 1), "0"]
                in_drone_menu = True
                continue
            in_drone_menu = False
            keys.append(str(nums[item]))
        buy = ", ".join(g + (" x%d" % n if n > 1 else "") for g, n in groups) or "nothing"
        # Same keys on PC and calculator: 1 opens the shop, 0 back, 0 fight.
        both = " ".join(["1"] + keys + ["0", "0"]) if keys else "0"
        q = leave_and_fight(p, level)
        tail = "" if q else "   <- you die here (expected)"
        # Columns stay 2+ spaces apart even when a field overflows, so the
        # key columns can still be parsed (see CLAUDE.md's regression check).
        cells = [col(have, 19), col(buy, 33), both + tail]
        rows.append(("%7d  " % level + " ".join(cells)).rstrip())
        if q is None:
            break
        p = q
    return rows


def parse_relic(text):
    if text == "none":
        return None
    return text.split(",") if "," in text else text


def _job(args):
    relic, artefact, cap, max_buys = args
    try:
        return relic, artefact, search(relic, artefact, cap, max_buys)[0]
    except MemoryError:
        return relic, artefact, None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("relic", nargs="?")
    ap.add_argument("artefact", nargs="?", default="none")
    ap.add_argument("--highest", type=int, help="try every relic/artefact unlocked at this highest")
    ap.add_argument("--frontier", type=int, default=20000, help="states kept per level (default 20000)")
    ap.add_argument("--max-buys", type=int, default=12, help="purchases per shop visit (default 12)")
    ap.add_argument("--rows", type=int, help="print only this many guide rows")
    ap.add_argument("--workers", type=int, default=4,
                    help="--highest: searches at once (default 4; each can use several GB)")
    a = ap.parse_args()

    if a.highest is not None:
        relics = [None] + fd.unlocked_relics(a.highest)
        artefacts = [None] + [x for x in fd.unlocked_artefacts(a.highest) if x != "carrier"]
        jobs = [(r, x, a.frontier, a.max_buys) for x in artefacts for r in relics]
        with Pool(a.workers, maxtasksperchild=1) as pool:
            results = pool.map(_job, jobs, chunksize=1)
        print("Carrier skipped (pass its 3 relics explicitly).")
        for relic, artefact, level in sorted(results, key=lambda t: -(t[2] or 0)):
            shown = "OOM" if level is None else "%3d" % level
            print("%3s  %s + %s" % (shown, relic or "none", artefact or "none"))
        return

    if not a.relic:
        ap.error("give a relic and artefact, or --highest")
    relic = parse_relic(a.relic)
    artefact = None if a.artefact == "none" else a.artefact
    level, path = search(relic, artefact, a.frontier, a.max_buys)
    print("Beats level %d%s" % (level, " (wins)" if level == fd.FINAL_LEVEL else ""))
    rows = guide_rows(relic, artefact, path)
    print("  Level  You have            Buy                               Keys (PC and calc)")
    print("\n".join(rows[:a.rows] if a.rows else rows))


if __name__ == "__main__":
    main()
