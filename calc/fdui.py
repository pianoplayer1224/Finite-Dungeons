# Port of section 5 (TERMINAL UI) of FiniteDungeons.py: shop screens.

from fdterm import say, ask, wait, status, G, R, paint
from fdval import *
from fddata import DRONE_TRACK_NAMES, DRONE_STAGE_DESCS
from fdshop import try_buy, activate_socks, take_water_sample, water_sample_reward
from fdshop import chicken_variant
from fdfight import switch_relic, buy_drone_upgrade
from fdevent import format_event, EVENT_COLOUR

S = str

UI = {"show_hits": True}
EVENT_LOG = None  # desktop tests set a list here


def pause():
    wait(MENU_PAUSE)


def render_events(events):
    for ev in events:
        if not UI["show_hits"] and ev["type"] in ("player_hit", "monster_hit"):
            continue
        kind = EVENT_COLOUR.get(ev["type"], "normal")
        for line in format_event(ev):
            if EVENT_LOG is not None:
                EVENT_LOG.append(line)
            say(paint(kind, line))


def stat_bar(player, level):
    status("HP " + S(player.hp) + "/" + S(player.max_hp) + "  $%.2f" % player.money
           + "  A" + S(player.total_atk()) + " D" + S(player.total_df())
           + " S" + S(player.total_spd()) + "  | Next: Lv" + S(level))


def shop_line(text, greyed):
    say(G + text + R if greyed else text)


def print_descriptions(title, keys, table):
    say("\n--- " + title + " DESCRIPTIONS ---")
    for k in keys:
        say(table.get(k, "No description."))
    ask("\nPress EXE to return...")


def drone_menu(player, level):
    """RAY-24 upgrade menu (shop option 1 with the drone relic)."""
    while True:
        stat_bar(player, level)
        d = player.drone
        say(paint("money", "Money: " + S(player.money)))
        say("RAY-24    Drone atk:" + S(d.atk) + "    Upgrade slot " + S(d.slots_used)
            + "/" + S(DRONE_SLOTS))
        for track in range(4):
            say("\n" + S(track + 1) + " " + DRONE_TRACK_NAMES[track] + "-stage "
                + S(d.stages[track]) + "/" + S(DRONE_STAGES))
            for stage in range(1, DRONE_STAGES + 1):
                desc = DRONE_STAGE_DESCS[track][stage - 1].format(
                    atk=d.atk, atk2=d.atk * DRONE_MISSILE_MULTIPLIER)
                shop_line(desc, stage > d.stages[track] + 1)
        say("\n0 return to shop")
        try:
            choice = int(ask("> "))
        except ValueError:
            say(paint("warning", "Invalid input, please try again."))
            continue
        if choice == 0:
            break
        if choice in (1, 2, 3, 4):
            render_events(buy_drone_upgrade(player, choice - 1))
            continue
        say(paint("warning", "Invalid input, please try again"))


BOOKS = (("atk", "Book of Attack (x" + S(BOOK_MULTIPLIER) + " atk)"),
         ("def", "Book of Defence (x" + S(BOOK_MULTIPLIER) + " def)"),
         ("spd", "Book of Speed (x" + S(BOOK_MULTIPLIER) + " spd)"),
         ("hp", "Book of Max HP (x" + S(BOOK_MULTIPLIER) + " max hp)"),
         ("heal", "Book of Healing (hp -> max hp)"))


def shop_menu(player, level):
    """Print the numbered shop list; returns {typed number: item}."""
    options = {}
    i = 1
    if player.relic == "yd":
        say(S(i) + " Ray-24 upgrade menu")
        options[S(i)] = "yds"
    elif player.relic != "e-sword" and not player.used_e_sword_before:
        left = LIMIT["sword"] - player.bought["sword"]
        shop_line(S(i) + " Sword (+" + S(FLAT_ITEM_GAIN) + " atk) - " + S(PRICE["sword"])
                  + " (" + S(left) + " left)", left == 0)
        options[S(i)] = "sword"
    else:
        left = LIMIT["battery"] - player.bought["battery"]
        shop_line(S(i) + " Battery for Countering - " + S(PRICE["battery"]) + " ("
                  + S(left) + " left)", left == 0)
        options[S(i)] = "battery"
    i += 1

    left = LIMIT["shield"] - player.bought["shield"]
    shop_line(S(i) + " Shield (+" + S(FLAT_ITEM_GAIN) + " def) - " + S(PRICE["shield"])
              + " (" + S(left) + " left)", left == 0)
    options[S(i)] = "shield"
    i += 1

    if player.artefact == "socks":
        shop_line(S(i) + " Boots (+" + S(FLAT_ITEM_GAIN) + " spd) - cannot buy due to Cursed "
                  "Socks-some bad curse will "
                  "occur if you try putting that sock into a sealed space, so this game "
                  "might crash", True)
    else:
        left = LIMIT["boots"] - player.bought["boots"]
        shop_line(S(i) + " Boots (+" + S(FLAT_ITEM_GAIN) + " spd) - " + S(PRICE["boots"])
                  + " (" + S(left) + " left)", left == 0)
        options[S(i)] = "boots"
    i += 1

    if player.relic in ("gk", "dk"):
        left = 1
        text = S(i) + " Chicken (heal max) - " + S(PRICE["chicken"]) + " (inf left)"
    else:
        card = chicken_variant(player.relic)
        left = CHICKEN_LIMIT[card] - player.bought["chicken"]
        text = (S(i) + " Chicken (+" + S(CHICKEN_HEAL[card]) + " hp if missing >="
                + S(CHICKEN_MIN_MISSING) + ") - " + S(PRICE["chicken"]) + " (" + S(left)
                + " left)")
    shop_line(text, left == 0)
    options[S(i)] = "chicken"
    i += 1

    for key, name in BOOKS:
        left = LIMIT["book"] - player.books[key]
        shop_line(S(i) + " " + name + " - " + S(PRICE["book"]) + " (" + S(left) + " left)",
                  left == 0)
        options[S(i)] = "book_" + key
        i += 1

    if player.artefact == "devotion":
        left = LIMIT["elixir"] - player.bought_elixir_this_visit
        shop_line(S(i) + " Elixir (*onster) - max hp-" + S(player.bought["elixir"] + 1)
                  + ", spd-" + S(ELIXIR_SPD_LOSS) + ", extra spd+" + S(ELIXIR_EXTRA_SPD)
                  + ", extra spd -" + S(ELIXIR_SPD_DECAY) + " after fight for "
                  + S(ELIXIR_FIGHTS) + " turns - " + S(PRICE["elixir"]) + " ("
                  + S(left) + " left)", left == 0)
        options[S(i)] = "elixir"
        i += 1

    if player.relic == "forbidden":
        left = LIMIT["ink"] - player.forbidden_ink_total
        shop_line(S(i) + " Forbidden Ink (insta-kill next monster when entering next fight)"
                  " - " + S(PRICE["ink"]) + " (" + S(left) + " left)", left == 0)
        options[S(i)] = "ink"
        i += 1

    say("0 Back")
    if player.artefact == "ar":
        say("235 Test water sample (max hp-" + S(AR_MAX_HP_LOSS) + ", money+"
            + S(water_sample_reward(player, level)) + ")")
    if player.artefact == "socks":
        say("777 Activate cursed socks")
    if player.artefact == "carrier":
        say("888 Switch to next relic (currently active: " + S(player.relic) + ")")
    return options


def shop(player, level, ac):
    """The shop submenu. Returns 'dead' if the player dies shopping, else None."""
    while True:
        pause()
        say("\n" + paint("money", "--- Shop ---   Money: %.2f" % player.money))
        options = shop_menu(player, level)

        stat_bar(player, level)
        choice = ask("> ")

        if choice == "0":
            return None
        if choice == "777" and player.artefact == "socks":
            render_events(activate_socks(player))
            continue
        if choice == "235" and player.artefact == "ar":
            events, dead = take_water_sample(player, level, ac)
            render_events(events)
            if dead:
                return "dead"
            continue
        if choice == "888" and player.artefact == "carrier":
            render_events(switch_relic(player))
            continue
        if choice not in options:
            say(paint("warning", "Invalid input, please try again"))
            continue

        item = options[choice]
        if item == "yds":
            drone_menu(player, level)
            continue

        events, dead = try_buy(player, item, ac)
        render_events(events)
        if dead:
            return "dead"
