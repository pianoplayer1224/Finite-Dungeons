# fdevent.py - turns engine events into text lines (fx-CG100).
# Hand-ported from format_event() in "FiniteDungeons.py" (no f-strings:
# MicroPython 1.9.4). All wording lives in fdtxt1/fddata.

from fdval import *
from fddata import RELIC_NAMES, DRONE_BUY_MSGS, VITALITY_PERCENT
from fdtxt1 import (BUY_BLOCKED_TEXT, SHOP_DEATH_TEXT, DRONE_BLOCKED_TEXT,
                    SOCKS_BLOCKED_TEXT, FORBIDDEN_MESSAGES, TRAMPLE_TEXT,
                    PIC_KILL_TEXT, SHOP_REVIVE_TEXT, AR_SAMPLE_TEXT)

S = str

# Colour of each event's lines (kinds are the keys of TEXT_COLOURS; missing = normal).
EVENT_COLOUR = {
    "buy_blocked": "warning", "purchased": "good", "shop_death": "bad",
    "socks_blocked": "warning", "socks_activated": "good", "water_sample": "story",
    "water_sample_blocked": "warning", "relic_switch_blocked": "warning",
    "drone_blocked": "warning", "drone_upgraded": "good",
    "vitality_penalty": "money", "coinpot_payout": "money",
    "smirk": "good", "drone_shot": "good", "drone_overkill": "good",
    "vitality_drain": "bad", "ink_kill": "good",
    "player_hit": "good", "monster_hit": "bad",
    "revive": "story", "pic_kill": "story",
    "book_hp_applied": "good", "book_hp_fizzled": "warning",
}


def capital(s):
    return s[:1].upper() + s[1:]


def format_event(ev):
    """Render one engine event into 0+ lines."""
    t = ev["type"]

    # --- shop ---
    if t == "buy_blocked":
        item, reason = ev["item"], ev["reason"]
        if item == "chicken" and ev.get("variant") == "gk" and reason == "money":
            return ["Cannot buy Chicken - not enough money"]
        if (item, reason) in BUY_BLOCKED_TEXT:
            return [BUY_BLOCKED_TEXT[(item, reason)]]
        if reason == "limit":
            return ["Cannot buy " + capital(item) + " - purchase limit reached."]
        if reason == "money":
            return ["Cannot buy " + capital(item) + " - not enough money."]
        return []

    if t == "purchased":
        item = ev["item"]
        if item == "chicken" and ev.get("variant") == "plain":
            return ["Chicken purchase successful"]
        if item == "book" and ev.get("key") == "hp":
            return ["Book of Max HP purchased! Max HP will double after your next fight."]
        if item == "ink":
            return ["Forbidden Ink purchased! (" + S(ev["total"])
                    + "/" + S(LIMIT["ink"]) + "). Enter the Battle and instant kill the monster!"]
        if item == "elixir":
            return ["You feel energised, your future self doesn't. SPD-" + S(ELIXIR_SPD_LOSS)
                    + ", extra spd +" + S(ELIXIR_EXTRA_SPD)]
        return []

    if t == "shop_death":
        return [SHOP_DEATH_TEXT[ev["cause"]]]

    if t == "socks_blocked":
        return [SOCKS_BLOCKED_TEXT[ev["reason"]]]

    if t == "socks_activated":
        return ["Cursed Socks activated!\n- ATK increased by " + S(ev["atk_gain"])
                + "\n- Max HP sealed at " + S(ev["max_hp"])]

    if t == "water_sample":
        return [AR_SAMPLE_TEXT.format(arb=ev["money"])]

    if t == "water_sample_blocked":
        return ["You can't risk in taking another sample of voidous venom(contaminated water)"]

    if t == "relic_switch_blocked":
        return ["Cannot switch: you are already on your last relic!"]

    if t == "relic_switched":
        return ["Your power is drained from activating multiple relics, stats go to "
                + S(CARRIER_RESET) + "!",
                "Active relic switched to: " + RELIC_NAMES[ev["relic"]]]

    if t == "meowton_equipped":
        return ["A law suit is not one that provides defence ability, DEF-" + S(MEOWTON_DEF_LOSS)]

    if t == "esword_equipped":
        if ev["had_sword"]:
            return ["You swapped your wooden sword from shop into the Automatic Counter E-Sword!"]
        return ["You equipped the Automatic Counter E-Sword! +" + S(ESWORD_ATK) + " ATK!"]

    # --- drone ---
    if t == "drone_blocked":
        return [DRONE_BLOCKED_TEXT[ev["reason"]]]

    if t == "drone_upgraded":
        return [DRONE_BUY_MSGS[ev["track"]][ev["stage"] - 1]]

    # --- pre-fight ---
    if t == "vitality_penalty":
        return ["Heart of Excessive Vitality drains %d%% of your money: -%.2f Money"
                % (VITALITY_PERCENT, ev["amount"]),
                "Apparently, being super healthy is expensive - your wallet got a protein shake tax!"]

    if t == "coinpot_payout":
        return ["Coinpot bonus: +%.2f money before fight!" % ev["amount"]]

    # --- combat ---
    if t == "smirk":
        return ["'Zako(pointless peasant)', you smirked"]

    if t == "drone_shot":
        head = ("a", "a second", "a third")[ev["shot"]]
        line = ("RAY-24 fires " + head + " Tomahawk Cruise Missile at the monster!\n"
                + "monster hp: " + S(ev["monster_hp_before"]) + "-" + S(ev["dmg"])
                + "=" + S(ev["monster_hp"]))
        if ev["shreds_df"]:
            line += ("    monster def: " + S(ev["monster_df_before"]) + "-"
                     + S(ev["df_loss"]) + "=" + S(ev["monster_df"]) + "(minimum 0)")
        return [line]

    if t == "drone_overkill":
        return ["Stop wasting ammo on dead bodies!"]

    if t == "vitality_drain":
        return ["weight of your wallet is draining your health, hp-" + S(ev["amount"])]

    if t == "ink_kill":
        if ev["final_boss"]:
            return ["Beat game special text not avalible in demo version"]
        return [FORBIDDEN_MESSAGES[ev["message_index"]]]

    if t == "player_hit":
        return ["\nYou deal " + S(ev["dmg"]) + " dmg!",
                "Your HP: " + S(ev["player_hp"]) + "       Monster's HP: "
                + S(ev["monster_hp_before"]) + "-" + S(ev["dmg"]) + "=" + S(ev["monster_hp"])]

    if t == "monster_hit":
        return ["\nMonster deals " + S(ev["dmg"]) + " dmg!",
                "Your HP: " + S(ev["player_hp_before"]) + "-" + S(ev["dmg"]) + "="
                + S(ev["player_hp"]) + "       Monster's HP: " + S(ev["monster_hp"])]

    if t == "revive":
        return [TRAMPLE_TEXT if ev["in_combat"] else SHOP_REVIVE_TEXT]

    if t == "pic_kill":
        return [PIC_KILL_TEXT]

    # --- post-fight ---
    if t == "book_hp_applied":
        return ["Book of Max HP activates! Your max HP is now " + S(ev["max_hp"]) + "."]

    if t == "book_hp_fizzled":
        return ["The Book of Max HP fizzles out against your sealed max HP. "
                "Cursed Socks don't negotiate."]

    raise ValueError("unknown event type: " + t)
