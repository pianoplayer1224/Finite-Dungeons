# Port of sections 2 (MODEL) and 3 (SAVE) of FiniteDungeons.py.

from fdval import *
from fddata import ACH_BIT_ORDER, SAVE_ALPHABET


class Entity:
    """Base class for player and monsters."""

    def __init__(self, hp, atk, df, spd):
        self.max_hp = hp
        self.hp = hp
        self.atk = atk
        self.df = df
        self.spd = spd
        self.extra_atk = 0
        self.extra_df = 0
        self.extra_spd = 0

    def total_atk(self):
        return self.atk + self.extra_atk

    def total_df(self):
        return self.df + self.extra_df

    def total_spd(self):
        return self.spd + self.extra_spd

    def is_alive(self):
        return self.hp > 0


class Drone:
    """RAY-24 state: four upgrade tracks (stage 0-DRONE_STAGES each), DRONE_SLOTS shared slots."""

    def __init__(self):
        self.atk = 0
        self.stages = [0, 0, 0, 0]
        self.slots_used = 0


class Player(Entity):
    """Player state: relic(s), artefact, money, purchases, drone, timers."""

    def __init__(self, relic, artefact):
        Entity.__init__(self, START_HP, START_STAT, START_STAT, START_STAT)
        self.money = START_MONEY
        self.artefact = artefact
        if artefact == "carrier":
            self.relics = list(relic)
            self.active_relic_index = 0
            self.relic = self.relics[0]
        else:
            self.relics = None
            self.relic = relic
        self.switches = 0

        self.revive_used = False
        self.revived_this_fight = False
        self.forbidden_ink = 0
        self.forbidden_ink_total = 0
        self.counters = 0
        self.used_e_sword_before = False
        self.coinpot_bonus = 0
        self.elixir_timers = []
        self.bought_elixir_this_visit = 0
        self.books = {"atk": 0, "def": 0, "hp": 0, "spd": 0, "heal": 0}
        self.bought = {"sword": 0, "shield": 0, "boots": 0, "chicken": 0,
                       "battery": 0, "elixir": 0}
        self.socks_sealed = False
        self.pending_hp_multiplier = 1
        self.ar_used = False
        self.vitality_drain_pending = False
        self.drone = Drone()

    # Methods, not properties: the calculator has no property().
    def total_atk(self):
        total = self.atk + self.extra_atk
        if self.relic == "yd":
            total += self.drone.atk
        if self.relic == "meowton":
            total += self.total_spd()
        return total


class Profile:
    """Persistent progress: run count, highest level beaten, achievements."""

    def __init__(self):
        self.runs = 0
        self.highest = 0
        self.ac = {}
        for key in ACH_BIT_ORDER:
            self.ac[key] = False


def create_monster(level):
    """Create monster stats based on level."""
    stat = level * MONSTER_GROWTH
    return Entity(stat + MONSTER_EXTRA_HP, stat, stat, stat)


# value = runs<<13 | highest<<8 | ach_bits, base-61 (no capital I), 5 characters.

def save_code(profile):
    bits = 0
    for key in ACH_BIT_ORDER:
        bits = (bits << 1) | (1 if profile.ac[key] else 0)

    # load_code() rejects runs > 1024.
    runs = min(profile.runs, 1024)
    value = (((runs << 5) | profile.highest) << 8) | bits

    code = ""
    while value > 0:
        code = SAVE_ALPHABET[value % 61] + code
        value //= 61
    while len(code) < 5:     # str.rjust is missing on MicroPython 1.9.4
        code = SAVE_ALPHABET[0] + code
    return code


def load_code(profile, code):
    """Decode a save code into profile. Returns (ok, message)."""
    if len(code) != 5:
        return False, "Invalid save code."
    for char in code:
        if char not in SAVE_ALPHABET:
            return False, "Invalid save code."

    value = 0
    for char in code:
        value = value * 61 + SAVE_ALPHABET.index(char)

    bits = value & 0xFF
    value >>= 8
    highest = value & 0x1F
    value >>= 5
    runs = value

    if runs > 1024 or highest > 30:
        return False, "Corrupted save code."

    profile.runs = runs
    profile.highest = highest
    for offset in range(len(ACH_BIT_ORDER)):
        profile.ac[ACH_BIT_ORDER[offset]] = bool((bits >> (7 - offset)) & 1)

    return True, ("\nSave loaded successfully.\nRuns: " + str(runs)
                  + "   Highest lv. beaten: " + str(highest) + "\n")
