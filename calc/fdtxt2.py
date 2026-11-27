from fdval import *
from fddata import VITALITY_PERCENT, AR_POWER_SIGN, VITALITY_DRAIN_TEXT

S = str

RELIC_DESCRIPTIONS = {
    'family': 'Picture of Family - Revives once to ' + S(REVIVE_HP) + ' HP when defeated.',
    'blessed': (
        'Blessed Emblem - Every ' + S(BLESSED_EVERY) + ' monsters defeated, +'
        + S(BLESSED_MAX_HP) + ' max HP and heal max. -' + S(BLESSED_START_HP_LOSS)
        + ' HP when run starts'
    ),
    'forbidden': (
        'Forbidden Book - unlocks in shop: ink - costs ' + S(PRICE['ink'])
        + ', max purchase ' + S(LIMIT['ink']) + ', max hold ' + S(INK_HOLD)
        + ', auto consumed at start of fight and defeats the monster.'
    ),
    'bk': ('K*C bronze membership card - chickens heal '
           + S(CHICKEN_HEAL['bk'] - CHICKEN_HEAL['plain']) + ' more hp, max purchase +'
           + S(CHICKEN_LIMIT['bk'] - CHICKEN_LIMIT['plain'])),
    'yd': 'RAY-24 Drone - have a drone to help you fight! Buy up to ' + S(DRONE_SLOTS) + ' upgrades',
    'e-sword': 'E-Sword - Starts with +' + S(ESWORD_ATK) + ' ATK.',
    'sk': ('K*C silver membership card - chickens heal '
           + S(CHICKEN_HEAL['sk'] - CHICKEN_HEAL['plain']) + ' more hp, max purchase +'
           + S(CHICKEN_LIMIT['sk'] - CHICKEN_LIMIT['plain'])),
    'meowton': (
        "Meowton's 2nd lawsuit - -" + S(MEOWTON_DEF_LOSS)
        + ' DEF when equipping, gain extra ATK = total SPD'
    ),
    'gk': 'K*C gold membership card - chickens heal max, no max purchase limit',
    'dk': (
        'K*C diamond membership card - chickens heal max, remove all conditions '
        'required to purchase chickens'
    ),
}

ARTEFACT_DESCRIPTIONS = {
    'devotion': (
        'The Damned Proof of Devotion - Elixir unlocked in shop - costs '
        + S(PRICE['elixir']) + ', max hp - [elixir bought], SPD-' + S(ELIXIR_SPD_LOSS)
        + ', extra spd+' + S(ELIXIR_EXTRA_SPD) + ', for next ' + S(ELIXIR_FIGHTS)
        + ' fights -' + S(ELIXIR_SPD_DECAY) + ' extra SPD after fight, can only buy '
        'one per turn.'
    ),
    'socks': (
        'Cursed Socks - Boots sealed. When HP <= ' + S(SOCKS_MAX_HP) + ', unlocks '
        'option in shop to decrease and seal max HP to current HP, gaining the same '
        'amount of ATK.'
    ),
    'coinpot': ("Alchemist's Coinpot - Every " + S(COINPOT_STEP)
                + ' money left before fight gives ' + S(COINPOT_PAY) + ' money.'),
    'ar': (
        'Abyssal Rad-Blood Oath - Unlocks a shop option once per run to lose '
        + S(AR_MAX_HP_LOSS) + ' max HP, gain money={level beaten/' + S(AR_LEVEL_STEP)
        + ' (round down)}' + AR_POWER_SIGN + '.'
    ),
    'carrier': (
        'Carrier of Legend - Choose ' + S(CARRIER_RELICS) + ' relics, switch from '
        'the 1st to 2nd to 3rd one. All stats except max hp drains to '
        + S(CARRIER_RESET) + ' at relic switch.'
    ),
    'vitality': (
        'Heart of Excessive Vitality - Start with ' + S(VITALITY_HP) + ' HP but lose '
        + S(VITALITY_PERCENT) + '% money before fights, at the start of fights, lose '
        'HP equal to ' + VITALITY_DRAIN_TEXT + '.'
    ),
}

INTRO = [
    '\nWelcome to FINITE DUNGEONS(demo)!',
    (
        'Long long ago, in the blessed town of...skipping opening cutscene?! How '
        'dare you...\nfine, straight to tutorial...'
    ),
    '--- How to play ---',
    (
        'This is an auto-combat game where life choices and shopping collide, '
        "and your aim is to defeat me, the level " + S(FINAL_LEVEL) + " boss. Why "
        "me? Shouldn't have "
        'skipped the intro if you want to know>:)\nCharacters have 4 stats: HP, '
        'ATK DEF and SPD.\nHP is shown in the form hp/max hp, others are shown in '
        "the form 'base+extra(total)'\nMonsters gain +" + S(MONSTER_GROWTH)
        + " to every stat each level, "
        'while you mainly increase stats by purchasing stuff in the shop before '
        "each fight, using a (creative) currency called 'money'.\nThe effect of "
        'each item is shown to the right of its name, followed by its price and '
        'purchase limit.\nTo purchase an item, simply input its number (found at '
        'its left) and enter, repeat if you want multiple purchases.\nAll stat '
        "increases refer to base stats unless 'extra' is specified.\nAt the start "
        "of runs you can pick (usually) 1 'relics' and 'artefacts', which you "
        'will unlock more as your highest level reached increases.\nWhen you get '
        'defeated you go back to level 1 and can start a new run, probably with '
        'new relics and artefacts you unlocked on the previous '
        'run.\n\n\n\n-------combat system------\nFighting in each level consists of 2 '
        'main phases: hitting the monster and getting hit by the monster, these '
        'two phases loop until the HP of you or the monster reaches 0.\nThe '
        "character with higher SPD hits first, if SPD ties, I'll let you hit "
        "first, cause I'm genuinely nice.\nWhen getting hit, HP decreases "
        'by:\nAttacker total ATK-Defender total DEF (HP lost is at least one if '
        'this gives <1)\nThis whole fight is automatic.\nThis is a pretty short '
        'game and any% should be easily under 2 mins, with 100% nowhere over 5 '
        'mins.\nGood luck, and I shall see you at level ' + S(FINAL_LEVEL) + '.\n\n'
    ),
]
