#!/usr/bin/env python3
"""Parity harness, Python side.

Replays tests/parity/scenarios.json and fuzz.json through ../pc/FiniteDungeons.py (the spec) and
writes canonical records that tests/parity/parity.gd writes identically from the GDScript
port. run_parity.sh diffs the two files.

Usage: python3 -I tests/parity/parity.py OUT_FILE

Real Python functions are called wherever they exist (engine, shop_menu, drone_menu,
pre_fight, print_library, ...). Only the glue in run() - which is interactive - is mirrored
here, marked GLUE. Keep the record format identical to parity.gd.
"""
import builtins
import contextlib
import importlib.util
import io
import json
import os
import re
import sys

sys.dont_write_bytecode = True   # no __pycache__ next to the spec / harness

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SPEC = os.path.join(os.path.dirname(ROOT), "pc", "FiniteDungeons.py")  # ROOT is godot/


def load_fd():
    spec = importlib.util.spec_from_file_location("finite_dungeons", SPEC)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)  # prints "color: command not found" on Linux; harmless
    mod.pause = lambda: None      # no MENU_PAUSE sleeps
    mod.UI["colours"] = False     # paint() returns plain text; GREY still marks greyed lines
    return mod


fd = load_fd()

# ---------------------------------------------------------------- serialisation
# Shared with parity.gd: None "~", bools T/F, ints plain, whole floats as ints, other floats
# as "f" + int(x * 2**32) (exact for these dyadic values), strings quoted with \\ \n \"
# escaped, lists [a,b], dicts {k:v} with sorted keys.


def ser(v):
    if v is None:
        return "~"
    if isinstance(v, bool):
        return "T" if v else "F"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        if v == int(v):
            return str(int(v))
        return "f" + str(int(v * 4294967296.0))
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"') + '"'
    if isinstance(v, (list, tuple)):
        return "[" + ",".join(ser(x) for x in v) + "]"
    if isinstance(v, set):
        return ser(sorted(v))
    if isinstance(v, dict):
        return "{" + ",".join(f"{k}:{ser(v[k])}" for k in sorted(v)) + "}"
    raise TypeError(f"cannot serialise {type(v)}")


ANSI = re.compile(r"\x1b\[[0-9;]*m")


def capture(fn, *args, inputs=None):
    """Run fn, returning its stdout as lines. GREY..RESET become «..»; input() is scripted."""
    feed = list(inputs or [])
    real_input = builtins.input
    builtins.input = lambda prompt="": feed.pop(0) if feed else "0"
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            result = fn(*args)
    finally:
        builtins.input = real_input
    text = buf.getvalue().replace(fd.GREY, "«").replace(fd.RESET, "»")
    text = ANSI.sub("", text)
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return lines, result


class Out:
    def __init__(self):
        self.lines = []

    def __call__(self, s):
        self.lines.append(s)


# ---------------------------------------------------------------- static sections

def values_names():
    src = open(SPEC, encoding="utf-8").read()
    block = src.split("# --- VALUES START ---")[1].split("# --- VALUES END ---")[0]
    return sorted(set(re.findall(r"^([A-Z_][A-Z0-9_]*)\s*=", block, re.M)))


CONTENT_NAMES = [
    "UNLOCK_LEVEL", "VITALITY_PERCENT", "AR_POWER_SIGN", "FORBIDDEN_MESSAGES", "RELIC_NAMES",
    "RELIC_DESCRIPTIONS", "ARTEFACT_MENU_NAMES", "ARTEFACT_DESCRIPTIONS", "ACH_BIT_ORDER",
    "ACHIEVEMENT_SECRET_HINTS", "ACHIEVEMENT_DISPLAY", "DRONE_TRACK_NAMES", "DRONE_STAGE_DESCS",
    "DRONE_BUY_MSGS", "TRAMPLE_TEXT", "PIC_KILL_TEXT", "SHOP_REVIVE_TEXT", "BLESSED_FUMBLE_TEXT",
    "AR_SAMPLE_TEXT", "BUY_BLOCKED_TEXT", "SHOP_DEATH_TEXT", "DRONE_BLOCKED_TEXT",
    "SOCKS_BLOCKED_TEXT", "EVENT_COLOUR", "SAVE_ALPHABET",
]


def content_value(name):
    v = getattr(fd, name)
    if name == "BUY_BLOCKED_TEXT":
        return {f"{k[0]}|{k[1]}": port_deviations(t, None) for k, t in v.items()}
    if name == "DRONE_BLOCKED_TEXT":
        return {k: port_deviations(t, None) for k, t in v.items()}
    if name in ("RELIC_DESCRIPTIONS", "ARTEFACT_DESCRIPTIONS"):
        return {k: description_dashes(t) for k, t in v.items()}
    if name == "AR_SAMPLE_TEXT":
        return v  # the {arb} placeholder is compared as-is
    return v


LIBRARY_HIGHEST = [0, 3, 4, 12, 29, 30]
ACH_SETS = [
    [],
    list(fd.ACH_BIT_ORDER),
    ["negative_money"],
    [k for k in fd.ACH_BIT_ORDER if k != "negative_money"],
    ["pic_kill", "shop_death", "trun", "drich"],
]
SAVE_RUNS = [0, 1, 2, 3, 7, 60, 61, 62, 100, 1023, 1024, 1025, 5000]
BAD_CODES = ["", "0000", "000000", "I0000", "0000I", "zzzzz", "00P92", "!!!!!", "0000O",
             "ABCDE", "00I00", "a b c", "Zzzzz", "10000", "0ZZZZ", "00000"]


def static_sections(out):
    for name in values_names():
        out(f"V {name} {ser(getattr(fd, name))}")
    for name in CONTENT_NAMES:
        out(f"C {name} {ser(content_value(name))}")

    lines, _ = capture(fd.print_intro)
    for line in lines:
        out("T intro " + line)
    lines, _ = capture(fd.print_credits)
    for line in lines:
        out("T credits " + line)
    for h in LIBRARY_HIGHEST:
        prof = fd.Profile()
        prof.highest = h
        lines, _ = capture(fd.print_library, prof)
        for line in lines:
            out(f"T library{h} " + line)
    for i, keys in enumerate(ACH_SETS):
        prof = fd.Profile()
        for k in keys:
            prof.ac[k] = True
        lines, _ = capture(fd.print_achievements, prof)
        for line in lines:
            out(f"T ach{i} " + line)

    for runs in SAVE_RUNS:
        bit_values = range(256) if runs in (0, 1024) else (0, 1, 2, 0x80, 0xAA, 0x55, 0xFF)
        for highest in range(31):
            for bits in bit_values:
                prof = fd.Profile()
                prof.runs, prof.highest = runs, highest
                for offset, key in enumerate(fd.ACH_BIT_ORDER):
                    prof.ac[key] = bool((bits >> (7 - offset)) & 1)
                code = fd.save_code(prof)
                back = fd.Profile()
                ok, msg = fd.load_code(back, code)
                out(f"S {runs} {highest} {bits} {code} {ser(ok)} {ser(msg)} {back.runs} {back.highest} {ser(back.ac)}")
    for code in BAD_CODES:
        prof = fd.Profile()
        prof.runs = 9
        ok, msg = fd.load_code(prof, code)
        out(f"S bad {ser(code)} {ser(ok)} {ser(msg)} {prof.runs} {prof.highest} {ser(prof.ac)}")


# ---------------------------------------------------------------- scenario replay

SNAP_FIELDS = [
    "hp", "max_hp", "atk", "df", "spd", "extra_atk", "extra_df", "extra_spd", "total_atk",
    "total_df", "total_spd", "money", "artefact", "relic", "relics", "active_relic_index",
    "switches", "revive_used", "revived_this_fight", "forbidden_ink", "forbidden_ink_total",
    "counters", "used_e_sword_before", "coinpot_bonus", "elixir_timers",
    "bought_elixir_this_visit", "books", "bought", "socks_sealed", "pending_hp_multiplier",
    "ar_used", "vitality_drain_pending",
]

# GLUE: colour kinds of the run-flow events, as run() prints them.
GLUE_COLOUR = {"esword_start": "normal", "meowton_equipped": "normal",
               "blessed_fumble": "story", "run_died": "bad", "hard_mode": "normal",
               "run_finished": "normal", "run_quit": "normal", "game_won": "good",
               "few_runs_win": "good"}


def snap(p):
    d = {}
    for f in SNAP_FIELDS:
        v = getattr(p, f, 0) if f == "active_relic_index" else getattr(p, f)  # only set for Carrier
        if f in ("artefact", "relic") and v is None:
            v = ""
        if f == "relics" and v is None:
            v = []
        d[f] = v
    d["drone_atk"] = p.drone.atk
    d["drone_stages"] = p.drone.stages
    d["drone_slots"] = p.drone.slots_used
    return d


class Run:
    def __init__(self, code):
        self.profile = fd.Profile()
        if code:
            fd.load_code(self.profile, code)
        self.player = None
        self.level = 1
        self.over = False


def engine_lines(events):
    """(event, lines, kind) for engine events, worded by the Python's format_event."""
    return [(ev, fd.format_event(ev), fd.EVENT_COLOUR.get(ev["type"], "normal")) for ev in events]


def glue(ev, lines):
    return (ev, lines, GLUE_COLOUR[ev["type"]])


def shop_death_end(r):
    """GLUE: run()'s "dead" branch."""
    lines, _ = capture(fd.end_of_run, r.profile, r.level)
    res = [glue({"type": "run_died", "level_completed": r.level - 1, "highest": r.profile.highest}, ["\n".join(lines)])]
    res.append(glue({"type": "run_finished", "runs": r.profile.runs}, [f"\nRun {r.profile.runs} finished! \n"]))
    r.over = True
    return res


def op_start(r, artefact, relic):
    """GLUE: run() up to the level loop."""
    p = r.profile
    p.runs += 1
    art = artefact or None
    rel = list(relic) if art == "carrier" else (relic or None)
    player = fd.Player(rel, art)
    res = []
    if player.relic == "e-sword":
        player.atk += fd.ESWORD_ATK
        res.append(glue({"type": "esword_start"}, [f"You have your own sword, not needing the shop one! +{fd.ESWORD_ATK} ATK!"]))
    if art == "vitality":
        player.max_hp = fd.VITALITY_HP
        player.hp = fd.VITALITY_HP
    if player.relic == "meowton":
        player.df -= fd.MEOWTON_DEF_LOSS
        res.append(glue({"type": "meowton_equipped"}, [f"A lawsuit is not one that provides defence ability, DEF-{fd.MEOWTON_DEF_LOSS}"]))
    blessed_packed = ("blessed" in player.relics) if player.relics else (player.relic == "blessed")
    if blessed_packed:
        player.hp -= fd.BLESSED_START_HP_LOSS
        res.append(glue({"type": "blessed_fumble"}, [fd.BLESSED_FUMBLE_TEXT]))
    r.player = player
    r.level = 1
    r.over = False
    return res, []


def op_fight(r):
    """pre_fight() with "0", then GLUE: run()'s level-loop body."""
    p, profile, level = r.player, r.profile, r.level
    lines, result = capture(fd.pre_fight, p, level, profile, inputs=["0"])
    assert result is None
    forecast = lines[8:]  # after "\n--- Level N ---", the 5 menu lines and the stat bar

    res = engine_lines(fd.vitality_money_penalty(p))
    res += engine_lines(fd.coinpot_payout(p))
    won, events = fd.fight(p, fd.create_monster(level), level, profile.ac)
    res += engine_lines(events)
    if not won:
        lines, _ = capture(fd.end_of_run, profile, level)
        res.append(glue({"type": "run_died", "level_completed": level - 1, "highest": profile.highest}, ["\n".join(lines)]))
        if p.money >= fd.RICH_MONEY:
            profile.ac["drich"] = True
        if level == fd.HARD_MODE_LEVEL and p.relic == "meowton" and p.artefact == "socks":
            profile.ac["hmode"] = True
            res.append(glue({"type": "hard_mode"}, ["I don't blame you, you just attempted the hardest difficulty"]))
        res.append(glue({"type": "run_finished", "runs": profile.runs}, [f"\nRun {profile.runs} finished! \n"]))
        r.over = True
        return res, forecast
    res += engine_lines(fd.post_fight(p, level))
    if level == fd.FINAL_LEVEL:
        res.append(glue({"type": "game_won"}, [f"\nYou beat level {fd.FINAL_LEVEL}. You win!"]))
        profile.highest = fd.FINAL_LEVEL
        if profile.runs <= fd.FEW_RUNS:
            profile.ac["trun"] = True
            res.append(glue({"type": "few_runs_win"}, ["You beat the game with the fewest runs possible!"]))
        r.over = True
    else:
        r.level += 1
    return res, forecast


def op_quit(r):
    """GLUE: run()'s "quit" branch."""
    r.profile.highest = max(r.profile.highest, r.level - 1)
    r.over = True
    return [glue({"type": "run_quit", "highest": r.profile.highest}, [f"\nYou left the dungeon. Highest: {r.profile.highest}"])], []


def apply_op(r, op):
    """Apply one op. Returns (results, extra_lines, died) or None if the op was skipped."""
    name = op[0]
    if name == "start":
        res, extra = op_start(r, op[1], op[2])
        return res, extra, False
    if name == "profile":
        prof = fd.Profile()
        ok, msg = fd.load_code(prof, op[1])
        if ok:
            r.profile = prof
        return [], [f"profile {ser(ok)} {ser(msg)}"], False
    if r.player is None or r.over:
        return None
    p, ac = r.player, r.profile.ac
    if name == "level":
        p.bought_elixir_this_visit = 0
        return [], [], False
    if name == "buy":
        events, dead = fd.try_buy(p, op[1], ac)
        res = engine_lines(events)
        if dead:
            res += shop_death_end(r)
        return res, [], dead
    if name == "drone":
        return engine_lines(fd.buy_drone_upgrade(p, int(op[1]))), [], False
    if name == "socks":
        return engine_lines(fd.activate_socks(p)), [], False
    if name == "water":
        events, dead = fd.take_water_sample(p, r.level, ac)
        res = engine_lines(events)
        if dead:
            res += shop_death_end(r)
        return res, [], dead
    if name == "switch":
        return engine_lines(fd.switch_relic(p)), [], False
    if name == "fight":
        res, forecast = op_fight(r)
        return res, forecast, False
    if name == "quit":
        res, extra = op_quit(r)
        return res, extra, False
    if name == "set":
        setattr(p, op[1], op[2])
        return [], [], False
    if name == "addmoney":
        p.money += op[1]
        return [], [], False
    if name == "setlevel":
        r.level = int(op[1])
        return [], [], False
    raise ValueError(f"unknown op {op}")


def port_deviations(line, p):
    """KNOWN DEVIATIONS: places where the port intentionally differs from the spec (owner
    decisions, PORT_PLAN.md §10). The Python line is rewritten to the port's wording so the
    rest of the record still compares. Keep this list short and documented."""
    # 888: the Python prints the active relic's key ("yd"); the port prints its name.
    if p is not None and line.startswith("888 Switch to next relic (currently active: "):
        return line.replace(f"(currently active: {p.relic})",
                            f"(currently active: {fd.RELIC_NAMES[p.relic]})")
    # "Not enough money": six phrasings in the Python, one template in the port.
    return MONEY_REFUSALS.get(line, line)


def description_dashes(text):
    """KNOWN DEVIATION: a relic/artefact description separates its name with " - " in the port
    (owner decision, PORT_PLAN.md §10); the Python mixes " — " and " - "."""
    return text.replace(" — ", " - ")


MONEY_REFUSALS = {
    "not enough money": "Cannot buy Chicken — not enough money.",
    "Cannot buy Chicken — not enough money": "Cannot buy Chicken — not enough money.",  # gold card
    "Not enough money.": "Cannot buy Book — not enough money.",
    "Cannot buy Battery — not enough money .": "Cannot buy Battery — not enough money.",
    "Not enough money for Forbidden Ink.": "Cannot buy Forbidden Ink — not enough money.",
    "Not enough money for the Elixir.": "Cannot buy Elixir — not enough money.",
    "Upgrade failed-not enough money": "Cannot buy upgrade — not enough money.",
}


def display(r, out):
    p, level = r.player, r.level
    out("B " + fd.stat_bar(p, level))
    lines, _ = capture(fd.shop_menu, p, level)
    for line in lines:
        out("M " + port_deviations(line, p))
    if p.relic == "yd":
        lines, _ = capture(fd.drone_menu, p, level, inputs=["0"])
        for line in lines[1:]:  # skip "Money: {money}" (Python str() of int-or-float)
            out("D " + line)
    lines, _ = capture(fd.display_player_and_next_monster, p, level)
    for line in lines:
        out("X " + line)


def replay(scenario, out):
    sname = scenario["name"]
    r = Run(scenario.get("code", "00000"))
    show = scenario.get("display", "all")
    for i, op in enumerate(scenario["ops"]):
        tag = f"{sname}#{i:03d} {op[0]}"
        applied = apply_op(r, op)
        if applied is None:
            out(f"O {tag} skip")
            continue
        res, extra, died = applied
        events = [ev for ev, _, _ in res]
        out(f"O {tag} ev={ser(events)} died={ser(died)}")
        for ev, lines, kind in res:
            for text in lines:
                for line in text.split("\n"):
                    out(f"L {kind}|{port_deviations(line, None)}")
        for line in extra:
            out("E " + port_deviations(line, None))
        prof = r.profile
        out(f"A runs={prof.runs} highest={prof.highest} ac={ser(prof.ac)} code={fd.save_code(prof)} level={r.level} over={ser(r.over)}")
        if r.player is not None:
            out("P " + ser(snap(r.player)))
            if not r.over and (show == "all" or op[0] in ("level", "start")):
                display(r, out)


def load_scenarios():
    scen = []
    for fname in ("scenarios.json", "fuzz.json"):
        path = os.path.join(HERE, fname)
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                scen += json.load(f)
    return scen


def main():
    out = Out()
    static_sections(out)
    for scenario in load_scenarios():
        replay(scenario, out)
    with open(sys.argv[1], "w", encoding="utf-8") as f:
        f.write("\n".join(out.lines) + "\n")


if __name__ == "__main__":
    main()
