from casioplot import clear_screen, show_screen, draw_string, getkey
from fdval import TEXT_COLOURS, COLOURS_ON

W, H = 384, 192
FONT = "small"
LINE_H = 11  # measured
ROWS = H // LINE_H
X0 = 2
MAX_W = W - 2 * X0
HISTORY = 400
LOOPS_PER_SEC = 120000  # busy-wait loops per second; there is no clock

BLACK = (0, 0, 0)
GREY = (140, 140, 140)
BLUE = (40, 90, 200)
G = "\x01"
R = "\x02"
MARK = {"muted": G, "story": "\x03", "good": "\x04", "bad": "\x05",
        "warning": "\x06", "money": "\x07"}
INK = {R: BLACK}
for _kind in list(MARK):
    if _kind in TEXT_COLOURS:
        INK[MARK[_kind]] = TEXT_COLOURS[_kind]
    else:
        del MARK[_kind]

# Key codes (row*10 + col), as measured on an fx-CG100.
DIGITS = {91: "0", 81: "1", 82: "2", 83: "3", 71: "4", 72: "5", 73: "6",
          61: "7", 62: "8", 63: "9"}
EXE, DEL, UP, DOWN, LEFT, RIGHT = 95, 64, 14, 34, 23, 25
MAX_TYPED = 9

# Advance widths are over-estimates, so a wrapped row can never overflow.
_W4 = "ijl.,:;'!|"
_W6 = " /\\()[]{}frtI\"`"

LOG = None  # desktop tests set a list here
rows = []
state = {"ink": R, "new": 0, "status": "", "colours": COLOURS_ON}


def cw(c):
    if c in _W4:
        return 4
    if c in _W6:
        return 6
    return 8


def paint(kind, text):
    if not state["colours"] or kind not in MARK:
        return text
    return MARK[kind] + text + R


def plain(text):
    return "".join([c for c in text if c not in INK])


def _lead(ink):
    return "" if ink == R else ink


def _wrap(line, ink):
    out = []
    start, w, sp, k, k_start, k_sp = 0, 0, -1, ink, ink, ink
    i = 0
    while i < len(line):
        c = line[i]
        if c in INK:
            k = c
        else:
            if c == " ":
                sp, k_sp = i, k
            w += cw(c)
            if w > MAX_W:
                if sp > start:
                    cut, nxt, k_next = sp, sp + 1, k_sp
                else:
                    cut, nxt, k_next = i, i, k
                out.append(_lead(k_start) + line[start:cut])
                start, k_start, sp = nxt, k_next, -1
                w = 0
                for j in range(start, i + 1):
                    if line[j] not in INK:
                        w += cw(line[j])
        i += 1
    out.append(_lead(k_start) + line[start:])
    return out, k


def say(*parts):
    text = " ".join([str(p) for p in parts])
    if LOG is not None:
        LOG.append(text)
    _add(text)


def _add(text):
    k = state["ink"]
    for line in text.split("\n"):
        wrapped, k = _wrap(line, k)
        rows.extend(wrapped)
    state["ink"] = R
    while len(rows) > HISTORY:  # list slice deletion may be compiled out
        rows.pop(0)
        state["new"] = max(0, state["new"] - 1)


def shell(*parts):
    # The Shell keeps its last 200 lines after the program stops: used for save codes.
    say(*parts)
    print(plain(" ".join([str(p) for p in parts])))


def fit(text):
    w = 0
    for i in range(len(text)):
        w += cw(text[i])
        if w > MAX_W:
            return text[:i]
    return text


def status(text=""):
    state["status"] = fit(text)


def _draw_row(y, row, color):
    x = X0
    seg = ""
    for c in row + R:
        if c in INK:
            if seg:
                draw_string(x, y, seg, color, FONT)
                for s in seg:
                    x += cw(s)
                seg = ""
            color = INK[c]
        else:
            seg += c


def _view():
    n = ROWS - 1 - (1 if state["status"] else 0)
    return (1 if state["status"] else 0), n


def _draw(top, entry):
    first, n = _view()
    clear_screen()
    if first:
        draw_string(X0, 0, state["status"], BLUE, FONT)
    for i in range(n):
        if top + i < len(rows):
            _draw_row((first + i) * LINE_H, rows[top + i], BLACK)
    y = (ROWS - 1) * LINE_H
    draw_string(X0, y, fit(entry + "_"), BLUE, FONT)
    bottom = max(0, len(rows) - n)
    marks = ("^" if top > 0 else " ") + ("v" if top < bottom else " ")
    draw_string(W - 20, y, marks, GREY, FONT)
    show_screen()


def key():
    # getkey() never waits: wait for release first, so one press is one action.
    while getkey():
        pass
    while True:
        k = getkey()
        if k:
            return k


def ask(prompt="> "):
    lead = prompt.split("\n")
    prompt = lead.pop()
    for line in lead:
        _add(line)
    n = _view()[1]
    bottom = max(0, len(rows) - n)
    top = bottom
    typed = ""
    while True:
        _draw(top, prompt + typed)
        k = key()
        if k in DIGITS:
            if len(typed) < MAX_TYPED:
                typed += DIGITS[k]
        elif k == DEL:
            typed = typed[:-1]
        elif k == UP:
            top = max(0, top - (n - 1))
        elif k == DOWN:
            top = min(bottom, top + (n - 1))
        elif k == LEFT:
            top = min(state["new"], bottom)
        elif k == RIGHT:
            top = bottom
        elif k == EXE:
            if not typed and top < bottom:
                top = min(bottom, top + (n - 1))
                continue
            _add(prompt + typed)
            state["new"] = len(rows)
            return typed


def ask_text(prompt):
    # Save codes need letters, which only the Shell's own input() can type.
    return input(prompt)


def wait(sec):
    for _ in range(int(sec * LOOPS_PER_SEC)):
        pass
