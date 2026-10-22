# fdval.py - every gameplay number for Finite Dungeons (fx-CG100).
# The block below is identical to section 0 (VALUES) of "FiniteDungeons.py":
# change both. The other modules read these with "from fdval import *".

# --- VALUES START ---
# Every number that decides how the game plays. The engine, the shop
# lines, the descriptions and the library all read these names, so
# changing a value here changes the rules AND the text explaining them.
# This block is identical in "FiniteDungeons.py" and calc/fdval.py:
# change both (CLAUDE.md has the check). Plain ASCII only.

# --- Runs and monsters ---
FINAL_LEVEL = 30           # beat this level to win (save codes store at most 31)
START_HP = 10              # max HP and HP when a run starts
START_STAT = 1             # ATK, DEF and SPD when a run starts
START_MONEY = 0            # money when a run starts
MONSTER_GROWTH = 1         # a level-L monster has L x this ATK, DEF and SPD,
MONSTER_EXTRA_HP = 4       #   and that + this many HP
WIN_MONEY = 4              # money for every monster beaten
MIN_DAMAGE = 1             # every hit does at least this much

# --- Shop: prices and limits ---
PRICE = {
    "sword": 2,            # ATK (not sold with the E-Sword or the Drone)
    "shield": 2,           # DEF
    "boots": 2,            # SPD (not sold with Cursed Socks)
    "chicken": 2,          # heals, see Chickens below
    "book": 3,             # every kind: Attack, Defence, Speed, Max HP, Healing
    "battery": 2,          # E-Sword only: counter-attacks
    "ink": 9,              # Forbidden Book only: kills the next monster outright
    "elixir": 2,           # Devotion only, see Artefacts below
}
LIMIT = {                  # how many you can buy in one run
    "sword": 1,
    "shield": 1,
    "boots": 1,
    "book": 3,             # of EACH kind of book
    "battery": 5,
    "ink": 10,             # one FORBIDDEN_MESSAGES line per ink: add lines if raised
    "elixir": 1,           # per shop visit, not per run
}
FLAT_ITEM_GAIN = 1         # Sword / Shield / Boots add this to ATK / DEF / SPD
BOOK_MULTIPLIER = 2        # Books of Attack / Defence / Speed / Max HP multiply
                           #   that stat (the Max HP book says "double")

# --- Chickens (the K*C membership card relics change them) ---
CHICKEN_HEAL = {"plain": 5, "bk": 8, "sk": 10}  # gold and diamond cards heal to max
CHICKEN_LIMIT = {"plain": 1, "bk": 2, "sk": 4}  # gold and diamond cards: no limit
CHICKEN_MIN_MISSING = 5    # plain/bronze/silver: sold only with this much HP missing

# --- Relics ---
REVIVE_HP = 1              # Picture of Family: revives you once, at this HP
BLESSED_EVERY = 3          # Blessed Emblem: after every 3rd level,
BLESSED_MAX_HP = 5         #   +5 max HP, then a full heal;
BLESSED_START_HP_LOSS = 1  #   -1 HP when a run starts with it packed
INK_HOLD = 1               # Forbidden Book: inks you can carry at once
ESWORD_ATK = 1             # E-Sword: ATK it gives when equipped
BATTERY_COUNTERS = 1       # E-Sword: counter-attacks per battery
MEOWTON_DEF_LOSS = 1       # Meowton's 2nd lawsuit: DEF lost when equipped

# --- RAY-24 Drone: 4 upgrade tracks, 4 stages each ---
DRONE_SLOTS = 6            # paid upgrades per run, all tracks together
DRONE_STAGES = 4           # stages per track (the lists below have one per stage)
DRONE_STAGE_COSTS = [      # price of each stage
    [1, 2, 3, 4],          # track 1 Hardpoint munition upgrade: drone ATK
    [2, 2, 2, 4],          # track 2 Alpha strike: missiles at the start of fights
    [2, 2, 2, 3],          # track 3 FARP Protocol: healing after each win
    [2, 2, 2, 3],          # track 4 Materiel Recovery: money after each win
]
DRONE_T1_ATK_GAIN = [1, 2, 2, 8]  # track 1: drone ATK each stage adds
DRONE_MISSILE_MULTIPLIER = 2      # track 2 from stage 2: a missile hits for drone
                                  #   ATK x this (the text says "double")
DRONE_STAGE4_MISSILES = 3         # track 2 stage 4: missiles per fight, each
DRONE_SHRED_MULTIPLIER = 2        #   cutting monster DEF by its damage x this
DRONE_HEALS = [10, 20, 50]        # track 3 stages 1-3: HP healed after a win
                                  #   (they add up: 10, then 30, then 80)
DRONE_HEAL_MULTIPLIER = 2         # track 3 stage 4: all healing x this ("doubles")
DRONE_T4_MONEY = [10, 16]         # track 4 stages 2-3: money after a win
                                  #   (stage 1 gives money = drone ATK)
DRONE_INCOME_MULTIPLIER = 2       # track 4 stage 4: all income x this ("double")

# --- Artefacts ---
ELIXIR_SPD_LOSS = 1        # Devotion's Elixir: -1 SPD and -[Elixirs bought] max HP,
ELIXIR_EXTRA_SPD = 6       #   +6 extra SPD,
ELIXIR_FIGHTS = 3          #   wearing off over the next 3 fights:
ELIXIR_SPD_DECAY = 2       #   -2 extra SPD after each of them
SOCKS_MAX_HP = 3           # Cursed Socks: activate at this HP or less
AR_MAX_HP_LOSS = 5         # Abyssal Rad-Blood Oath: the water sample (once per run)
AR_LEVEL_STEP = 5          #   costs 5 max HP and pays
AR_POWER = 4               #   (levels beaten // 5) ** this money
COINPOT_STEP = 3           # Alchemist's Coinpot: every 3 money left when you leave
COINPOT_PAY = 2            #   the shop pays 2 money before the fight
VITALITY_HP = 50           # Heart of Excessive Vitality: start with 50 max HP and HP,
VITALITY_MONEY_LOSS = 0.10 #   lose this share of your money before each fight,
VITALITY_DRAIN_DIVISOR = 1 #   then lose HP = money / this
CARRIER_RELICS = 3         # Carrier of Legend: relics packed (switches = this - 1);
CARRIER_RESET = 1          #   HP, ATK, DEF and SPD drop to this at a switch

# --- Unlocks: (key, highest level beaten needed). List order = menu order. ---
RELIC_UNLOCKS = [
    ("family", 0),
    ("blessed", 0),
    ("forbidden", 0),
    ("e-sword", 999999),   # kept out of the game until it is balanced
    ("bk", 2),
    ("sk", 7),
    ("yd", 8),
    ("gk", 10),
    ("meowton", 15),
    ("dk", 30),
]
ARTEFACT_UNLOCKS = [
    ("devotion", 3),
    ("socks", 6),
    ("ar", 12),
    ("coinpot", 18),
    ("carrier", 20),
    ("vitality", 20),
]

# --- Achievements ---
RICH_MONEY = 25000000      # "you can't take it with you": die holding this much
FEW_RUNS = 3               # "The real game": beat FINAL_LEVEL within this many runs
HARD_MODE_LEVEL = 2        # "hard mode": die on this level with Meowton + Cursed Socks

# --- Interface ---
MENU_PAUSE = 0.3           # seconds of pause before the shop and main menu redraw
TEXT_COLOURS = {           # RGB colour of each kind of text (both screens are white)
    "muted": (160, 160, 160),    # greyed-out items, flavour lines, the fight forecast
    "story": (100, 100, 100),    # story scenes
    "good": (0, 128, 0),         # your hits, heals, purchases, wins
    "bad": (190, 0, 0),          # monster hits, drains, deaths
    "warning": (190, 0, 0),      # blocked purchases, invalid input
}                          # anything else (menus, stats, headings, money) is
                           # the normal text colour. Money lines are marked
                           # "money": add a "money" entry here to colour them.
COLOURS_ON = True          # colours at start; players can switch them off in-game
# --- VALUES END ---
