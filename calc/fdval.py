# --- VALUES START ---
# Generated from balance.yaml by tools/balance.py: edit that, not this block. ASCII only.

FINAL_LEVEL = 30           # save codes store at most 31
START_HP = 10
START_STAT = 1
START_MONEY = 0
MONSTER_GROWTH = 1
MONSTER_EXTRA_HP = 4
WIN_MONEY = 4
MIN_DAMAGE = 1

PRICE = {
    "sword": 2,
    "shield": 2,
    "boots": 2,
    "chicken": 2,
    "book": 3,
    "battery": 2,
    "ink": 9,
    "elixir": 2,
}
LIMIT = {
    "sword": 1,
    "shield": 1,
    "boots": 1,
    "book": 3,
    "battery": 5,
    "ink": 10,             # one FORBIDDEN_MESSAGES line per ink: add lines if raised
    "elixir": 1,
}
FLAT_ITEM_GAIN = 1
BOOK_MULTIPLIER = 2        # the Max HP book text says "double"

CHICKEN_HEAL = {"plain": 5, "bk": 8, "sk": 10}
CHICKEN_LIMIT = {"plain": 1, "bk": 2, "sk": 4}
CHICKEN_MIN_MISSING = 5

REVIVE_HP = 1
BLESSED_EVERY = 3
BLESSED_MAX_HP = 5
BLESSED_START_HP_LOSS = 1
INK_HOLD = 1
ESWORD_ATK = 1
BATTERY_COUNTERS = 1
MEOWTON_DEF_LOSS = 1

DRONE_SLOTS = 6
DRONE_STAGES = 4
DRONE_STAGE_COSTS = [
    [1, 2, 3, 4],
    [2, 2, 2, 4],
    [2, 2, 2, 3],
    [2, 2, 2, 3],
]
DRONE_T1_ATK_GAIN = [1, 2, 2, 8]
DRONE_MISSILE_MULTIPLIER = 2      # the text says "double"
DRONE_STAGE4_MISSILES = 3
DRONE_SHRED_MULTIPLIER = 2
DRONE_HEALS = [10, 20, 50]
DRONE_HEAL_MULTIPLIER = 2         # the text says "doubles"
DRONE_T4_MONEY = [10, 16]
DRONE_INCOME_MULTIPLIER = 2       # the text says "double"

ELIXIR_SPD_LOSS = 1
ELIXIR_EXTRA_SPD = 9
ELIXIR_FIGHTS = 3
ELIXIR_SPD_DECAY = 3
SOCKS_MAX_HP = 5
AR_MAX_HP_LOSS = 5
AR_LEVEL_STEP = 5
AR_POWER = 4
COINPOT_STEP = 3
COINPOT_PAY = 2
VITALITY_HP = 50
VITALITY_MONEY_LOSS = 0.10
VITALITY_DRAIN_DIVISOR = 1
CARRIER_RELICS = 3
CARRIER_RESET = 1

# List order = menu order: add new unlocks at the end.
RELIC_UNLOCKS = [
    ("family", 0),
    ("blessed", 0),
    ("forbidden", 0),
    ("e-sword", 999999),   # kept out of the game until it is balanced
    ("bk", 2),
    ("sk", 6),
    ("yd", 8),
    ("gk", 10),
    ("meowton", 15),
    ("dk", 30),
]
ARTEFACT_UNLOCKS = [
    ("devotion", 3),
    ("socks", 5),
    ("ar", 12),
    ("coinpot", 18),
    ("carrier", 20),
    ("vitality", 20),
]

RICH_MONEY = 32000000
FEW_RUNS = 3
HARD_MODE_LEVEL = 2

MENU_PAUSE = 0.3
# "money" has no entry on purpose: add one to colour money lines.
TEXT_COLOURS = {
    "muted": (160, 160, 160),
    "story": (100, 100, 100),
    "good": (0, 128, 0),
    "bad": (190, 0, 0),
    "warning": (190, 0, 0),
}
COLOURS_ON = True
# --- VALUES END ---
