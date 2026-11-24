from fdval import *
from fddata import UNLOCK_LEVEL, VITALITY_PERCENT, AR_POWER_SIGN, VITALITY_DRAIN_TEXT

S = str


def U(key):
    return '\x01(unlocks after beating lv. ' + S(UNLOCK_LEVEL[key]) + ')\x02'


LIB_HEAD = [
    '\n---relics---',
    'Picture of Family \nRevives once to ' + S(REVIVE_HP) + ' HP when defeated.',
    "\x01'If you don't believe in yourself, believe in me who believe in you'\n\x02",
    (
        'Blessed Emblem \nEvery ' + S(BLESSED_EVERY) + ' monsters defeated, +'
        + S(BLESSED_MAX_HP) + ' max HP and fully heals. hp-' + S(BLESSED_START_HP_LOSS)
        + ' when run starts'
    ),
    '\x01This Emblem is really blessed, definitely, trust.\n\x02',
    (
        'Forbidden Book \nUnlocks in the shop: ink-costs ' + S(PRICE['ink'])
        + ', max purchase ' + S(LIMIT['ink']) + ', max hold ' + S(INK_HOLD)
        + ', automatically consumed at start of fight and defeats the monster.'
    ),
    '\x01What can be more cursed than a book full of equations?\n\x02',
    (
        'K*C bronze membership card ' + U('bk') + ' \nChickens heal '
        + S(CHICKEN_HEAL['bk'] - CHICKEN_HEAL['plain']) + ' more HP'
    ),
    '\x01A membership card that gets you extra food on order!\n\x02',
    (
        'K*C silver membership card ' + U('sk') + ' \nChickens heal '
        + S(CHICKEN_HEAL['sk'] - CHICKEN_HEAL['plain']) + ' more HP, max purchase +'
        + S(CHICKEN_LIMIT['sk'] - CHICKEN_LIMIT['plain'])
    ),
    (
        "\x01Don't ask how a membership card increases stock, it's what you call a "
        "'Fantasy world'\n\x02"
    ),
    (
        'RAY-24 Drone ' + U('yd') + ' \nHave a drone to help you fight, having extra '
        'atk=its atk! Buy up to ' + S(DRONE_SLOTS) + ' accumulative upgrades'
    ),
    (
        '\x01This relic is made in respect to my friend who managed to looked '
        'through this unimaginable messy code and spent a few hours given me '
        'insights\n\x02'
    ),
    (
        'K*C gold membership card ' + U('gk') + ' \nChickens heal max, no max '
        'purchase limit'
    ),
    (
        "\x01Shouldn't infinite K*C chicken damage your health? Anyways, eating "
        'ALWAYS heals...\n\x02'
    ),
    (
        "Meowton's 2nd lawsuit " + U('meowton') + ' \n-' + S(MEOWTON_DEF_LOSS)
        + ' DEF upon equipping, gain extra ATK = total SPD'
    ),
    (
        "\x01I know Newton's 2nd law is multiply, but I need to consider game "
        'balance ok?\n\x02'
    ),
]

LIB_LOCKED = ['????????' + U('dk') + ' \n???????????\n']

LIB_DIAMOND = [
    (
        'K*C diamond membership card ' + U('dk') + ' \nChickens heal max, remove all '
        'conditions required to purchase chickens\n'
    ),
    (
        "\x01Sorry for the 'yet another K*C card' disappointment, I am not a very "
        'creative person\x02'
    ),
]

LIB_TAIL = [
    '---artefacts--',
    (
        'The Damned Proof of Devotion ' + U('devotion') + ' \nElixir unlocked in '
        'shop: costs ' + S(PRICE['elixir']) + ', max HP - [elixir bought], SPD-'
        + S(ELIXIR_SPD_LOSS) + ', extra SPD+' + S(ELIXIR_EXTRA_SPD) + '; for next '
        + S(ELIXIR_FIGHTS) + ' fights, -' + S(ELIXIR_SPD_DECAY) + ' extra SPD after '
        'fight, can only buy one per turn.'
    ),
    "\x01But to some soul, isn't energy drinks their only 'elixir'?\n\x02",
    (
        'Cursed Socks ' + U('socks') + ' \nBoots sealed. When HP <= ' + S(SOCKS_MAX_HP)
        + ', unlocks option in the shop to decrease and seal max HP to current '
        'HP, gaining the same amount of ATK.'
    ),
    (
        "\x01Socks in certain conditions can really have a high ATK, don't find it "
        'out the hard way...\n\x02'
    ),
    (
        'Abyssal Rad-Blood Oath ' + U('ar') + ' \nUnlocks a shop option once per '
        'run to lose ' + S(AR_MAX_HP_LOSS) + ' max HP, gain money = {level beaten/'
        + S(AR_LEVEL_STEP) + ' (round down)}' + AR_POWER_SIGN + '.'
    ),
    (
        '\x01A contract to test suspicious water samples in the dungeon, a world '
        "without power oppression wouldn't be a realistic one, would it?\n\x02"
    ),
    (
        "Alchemist's Coinpot " + U('coinpot') + ' \nEvery ' + S(COINPOT_STEP)
        + ' money left before fight gives ' + S(COINPOT_PAY) + ' money.'
    ),
    (
        '\x01So...do the monsters transfer money to you digitally when they get '
        'defeated?\n\x02'
    ),
    (
        'Heart of Excessive Vitality ' + U('vitality') + ' \nStart with '
        + S(VITALITY_HP) + ' HP but lose ' + S(VITALITY_PERCENT) + '% money before '
        'fights, at start of fight HP - ' + VITALITY_DRAIN_TEXT + '.'
    ),
    (
        "\x01I hope that is the right use of 'vitality', I don't fully understand "
        'that word till this day\n\x02'
    ),
    (
        'Carrier of Legend ' + U('carrier') + ' \nChoose ' + S(CARRIER_RELICS)
        + ' relics, switch from the 1st to 2nd to 3rd one. All stats except max HP '
        'drain to ' + S(CARRIER_RESET) + ' at relic switch.'
    ),
    (
        '\x01The biggest relic is a drone, so the volume of this bag is '
        'realistic...I hope?\n\x02'
    ),
]
