"""Desktop stand-in for the fx-CG100's casioplot module (draws nothing).

Lets calc/ run on a PC for tests (see fuzz_compare.py). Keys never arrive
through getkey() here: the tests replace fdterm.ask() instead.
"""


def clear_screen():
    pass


def show_screen():
    pass


def draw_string(x, y, text, color=(0, 0, 0), size="medium"):
    pass


def getkey():
    return None
