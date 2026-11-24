# Port of section 1 (CONTENT DATA) of FiniteDungeons.py.

from fdval import *

S = str

RELIC_NAMES = {
    'family': 'Picture of Family',
    'blessed': 'Blessed Emblem',
    'forbidden': 'Forbidden Book',
    'bk': 'K*C bronze membership card',
    'e-sword': 'Automatic Counter E-Sword',
    'yd': 'RAY-24 Drone',
    'sk': 'K*C silver membership card',
    'meowton': "Meowton's Second Lawsuit",
    'gk': 'K*C gold membership card',
    'dk': 'K*C diamond membership card',
}

ARTEFACT_MENU_NAMES = {
    'devotion': 'The Damned Proof of Devotion (i.e. corner shop loyalty card)',
    'socks': 'Cursed (old, smelly) Socks',
    'coinpot': "Alchemist's Coinpot (savings account)",
    'ar': 'Abyssal Rad-Blood Oath (suspicious nuclear food testing contract)',
    'carrier': 'The carrier of legends (Backpack)',
    'vitality': 'Heart of Excessive Vitality (Protein shake heath package plan)',
}

UNLOCK_LEVEL = dict(RELIC_UNLOCKS + ARTEFACT_UNLOCKS)
VITALITY_PERCENT = int(round(VITALITY_MONEY_LOSS * 100))
AR_POWER_SIGN = "^" + S(AR_POWER)
VITALITY_DRAIN_TEXT = "money" if VITALITY_DRAIN_DIVISOR == 1 else "money/" + S(VITALITY_DRAIN_DIVISOR)

ACH_BIT_ORDER = ('pic_kill', 'negative_money', 'shop_death', 'one_shot', 'trun', 'okill', 'drich', 'hmode')

ACHIEVEMENT_SECRET_HINTS = set(['negative_money'])

ACHIEVEMENT_DISPLAY = [
    ('trun', 'The real game', 'beat level ' + S(FINAL_LEVEL) + ' in ' + S(FEW_RUNS) + ' runs'),
    ('drich', "you can't take it with you", 'die with over ' + S(RICH_MONEY // 1000000) + 'm money'),
    ('one_shot', 'Zako', 'one shot a monster'),
    (
        'okill',
        "'just in case its still alive, you know?'",
        'shoot a Tomahawk Cruise Missile at a dead monster',
    ),
    ('hmode', 'hard mode', 'inevitably die on level ' + S(HARD_MODE_LEVEL)),
    (
        'negative_money',
        'Well, you did say ALL conditions',
        'purchase a chicken without enough money',
    ),
    ('shop_death', "as dangerous as 'monster'", 'die in shop'),
    ('pic_kill', 'one hp actually helps?!', 'kill a monster after reviving'),
]

DRONE_TRACK_NAMES = ['Hardpoint munition upgrade', 'Alpha strike', 'FARP Protocol', 'Materiel Recovery']

# {atk}/{atk2} are filled in by drone_menu().
_C = DRONE_STAGE_COSTS
DRONE_STAGE_DESCS = [
    [
        'Stage 1-drone atk +' + S(DRONE_T1_ATK_GAIN[0]) + ', cost: ' + S(_C[0][0]),
        'Stage 2-drone atk +' + S(DRONE_T1_ATK_GAIN[1]) + ', cost: ' + S(_C[0][1]),
        'Stage 3-drone atk +' + S(DRONE_T1_ATK_GAIN[2]) + ', cost: ' + S(_C[0][2]),
        'Stage 4-drone atk +' + S(DRONE_T1_ATK_GAIN[3]) + ', cost: ' + S(_C[0][3]),
    ],
    [
        (
            'Stage 1-at start of fight fire Tomahawk Cruise Missile, attacking '
            'monster with drone atk({atk}), cost: ' + S(_C[1][0])
        ),
        'Stage 2-the Tomahawk Cruise Missile has double atk, cost: ' + S(_C[1][1]),
        (
            'Stage 3-Tomahawk Cruise Missile penetrate defence=its attack({atk2}), '
            'cost: ' + S(_C[1][2])
        ),
        (
            'Stage 4-fires ' + S(DRONE_STAGE4_MISSILES - 1) + ' more Tomahawk Cruise '
            'Missiles, Tomahawk Cruise Missiles decrease monster defence=their dmg*'
            + S(DRONE_SHRED_MULTIPLIER) + ', cost: ' + S(_C[1][3])
        ),
    ],
    [
        'Stage 1-when you defeat a monster heal ' + S(DRONE_HEALS[0]) + ', cost: ' + S(_C[2][0]),
        (
            'Stage 2-heal max, when you defeat a monster heal ' + S(sum(DRONE_HEALS[:2]))
            + ', cost: ' + S(_C[2][1])
        ),
        (
            'Stage 3-heal max, when you defeat a monster heal ' + S(sum(DRONE_HEALS[:3]))
            + ', cost: ' + S(_C[2][2])
        ),
        'Stage 4-heal max, healings(from all source) doubles, cost: ' + S(_C[2][3]),
    ],
    [
        'Stage 1-when you defeat a monster +money = drone atk, cost: ' + S(_C[3][0]),
        (
            'Stage 2-when you defeat a monster +' + S(DRONE_T4_MONEY[0]) + ' money, upgrade '
            "all stage 1 upgrades into stage 2(doesn't take up one of the "
            + S(DRONE_SLOTS) + ' slots), cost: ' + S(_C[3][1])
        ),
        (
            'Stage 3-when you defeat a monster +' + S(DRONE_T4_MONEY[1]) + ' money, make all '
            'upgrades at least stage 1(does not take up slot), cost: ' + S(_C[3][2])
        ),
        (
            'Stage 4-double income (from all sources), upgrade all stage 3 into '
            "stage 4(doesn't take up slot), cost: " + S(_C[3][3])
        ),
    ],
]

DRONE_BUY_MSGS = [
    [
        'upgrade purchased, drone atk + ' + S(DRONE_T1_ATK_GAIN[0]),
        'upgrade purchased, drone atk + ' + S(DRONE_T1_ATK_GAIN[1]),
        'upgrade purchased, drone atk + ' + S(DRONE_T1_ATK_GAIN[2]),
        'upgrade purchased, drone atk + ' + S(DRONE_T1_ATK_GAIN[3]),
    ],
    [
        'Upgrade purchased, drone will attack at start of fight!',
        'upgrade purchased, Tomahawk Cruise Missile atk*' + S(DRONE_MISSILE_MULTIPLIER),
        'Upgrade purchased, Tomahawk Cruise Missiles will now penetrate defence!',
        (
            'Upgrade purchased, drone will now fire ' + S(DRONE_STAGE4_MISSILES - 1)
            + ' more Tomahawk Cruise Missiles and they reduce monster def!'
        ),
    ],
    [
        'upgrade purchased, drone will now heal you after fight!',
        'upgrade purchased, drone healed you max will now heal more after fight!',
        'upgrade purchased, drone healed you max will now heal more after fight!',
        'upgrade purchased, drone will now double your heal!',
    ],
    [
        'upgrade purchased, drone will give extra money after fight!',
        (
            'upgrade purchased, drone is developed and will give extra money after '
            'fight!'
        ),
        (
            'upgrade purchased, drone is developed and will give extra money after '
            'fight!'
        ),
        'upgrade purchased, drone is enhanced and will double your income!',
    ],
]

SAVE_ALPHABET = '0123456789ABCDEFGHJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
