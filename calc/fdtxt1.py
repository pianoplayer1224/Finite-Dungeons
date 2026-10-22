# fdtxt1.py - game messages for Finite Dungeons (fx-CG100).
# Mirrors the PC game's messages in ASCII; numbers come from fdval.py.

from fdval import *

S = str

BUY_BLOCKED_TEXT = {
    ('chicken', 'limit'): 'Cannot buy Chicken - purchase limit reached.',
    ('chicken', 'money'): 'not enough money',
    ('chicken', 'hp_full'): (
        'Cannot buy Chicken - your hp is too high and would waste food if you '
        'bought chicken!'
    ),
    ('book', 'limit'): 'Cannot buy Book - purchase limit reached.',
    ('book', 'money'): 'Not enough money.',
    ('book', 'sealed'): "max hp sealed by socks, don't ask how or why",
    ('battery', 'limit'): 'Cannot buy Battery - purchase limit reached.',
    ('battery', 'money'): 'Cannot buy Battery - not enough money .',
    ('battery', 'no_esword'): 'Your current sword is wooden, nowhere to put in battery!',
    ('ink', 'max'): (
        "You can't write another formula down again, it hurt too much when you "
        'got laughed at last time!'
    ),
    ('ink', 'held'): (
        "You already have a Forbidden Ink in your pocket, don't be greedy, ink "
        'spills easily!'
    ),
    ('ink', 'money'): 'Not enough money for Forbidden Ink.',
    ('elixir', 'visit_limit'): 'Cannot buy Elixir - turn purchase limit reached.',
    ('elixir', 'money'): 'Not enough money for the Elixir.',
    ('boots', 'socks'): 'Cannot buy Boots - no Cursed Socks inside sealed spaces.',
}

SHOP_DEATH_TEXT = {
    'elixir': (
        "\nYou chug the elixir, hope it tasted good, as it's the last one you "
        'had.\n'
    ),
    'water_sample': (
        '\nThe Blight was more cursed than radioactive - your body gives out '
        'right there in the shop.\n'
    ),
}

DRONE_BLOCKED_TEXT = {
    'slots': 'Upgrade failed-slot is full.',
    'max': 'This upgrade is already at maximum level.',
    'money': 'Upgrade failed-not enough money',
}

SOCKS_BLOCKED_TEXT = {
    'already': 'Cursed Socks are already activated.',
    'hp_too_high': 'Cursed Socks cannot activate unless HP is ' + S(SOCKS_MAX_HP) + ' or less.',
}

FORBIDDEN_MESSAGES = [
    (
        'You wrote out the formula to beat this game (a wrong one), the monster '
        'dies laughing!'
    ),
    (
        'You wrote out Navier-Stokes equation, the monster dies trying to '
        'understand!'
    ),
    "You wrote out Einstein's field equations, the monster dies overwhelmed!",
    "You wrote out Schrodinger's equation, the monster dies in confusion!",
    "You scribbled down Maxwell's equations, the monster dies from panic!",
    'You wrote out Rocket propulsion formulas, the monster dies screaming!',
    "You jotted down Euler's formula, the monster dies in horror!",
    'You wrote out the cubic formula, the monster faints and dies!',
    'You scribbled out the Pythagorean theorem, the monster dies of fright!',
    (
        'You wrote out the equation for the area of a triangle, the monster got '
        'scared to death!'
    ),
]

TRAMPLE_TEXT = (
    'Harshly, you are shuffled to the ground. Out of your pocket a picture '
    'flew out, the picture that stands as your fuel, the picture that '
    'supported you up to here, the picture that captures the moment you can '
    'never return to...\nthen TRASH\nnot dramatically, not emotionally, the '
    'monster trampled on it.\nYou feel a string snapped inside you as the '
    'picture shattered into pieces.\nBefore you knew it, you were charging '
    'towards the monster with all your might...'
)

PIC_KILL_TEXT = (
    'From that burst of energy not explainable by science, you regained just '
    'enough power to put the down the monster before dropping to the '
    'ground\nAfter what felt like eternities later, you dragged yourself up, '
    'and moved on, just like what they would have wanted to see...'
)

SHOP_REVIVE_TEXT = (
    'Your knees buckle, and the picture slips out of your pocket, landing '
    'face-down in the dirt.\nNo monster, no dramatic music, no one to blame - '
    'just you, a shop, and a photograph you will never be able to look at '
    'the same way again.\nYou pick yourself up anyway. They would have wanted '
    'you to.'
)

BLESSED_FUMBLE_TEXT = (
    'You fumble with the Blessed Emblem while getting ready and pinched '
    'yourself, losing ' + S(BLESSED_START_HP_LOSS)
    + ' HP.....\nI am not laughing at you, I promise.'
)

AR_SAMPLE_TEXT = (
    'You collected some Blight (glowing water) in the dungeon, despite '
    'knowing it is radioactive(crused), you still decided to betray your '
    'DNA(soul) and melded with(drank) it.\nReading your treatise(report), the '
    'demons(people at the summit of glorious achievement) decided to '
    'bestow(reward) you with {arb} money, given the deepness the sample is '
    'from.\nYou feel your body is already regretting this decision, max hp -'
    + S(AR_MAX_HP_LOSS) + '!'
)
