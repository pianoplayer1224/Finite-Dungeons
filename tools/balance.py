#!/usr/bin/env python3
"""Write the values in balance.yaml into every edition of the game.

balance.yaml is the one place to change a balance value. This script renders
the templates in tools/balance_templates/ with its values and writes:

    pc/FiniteDungeons.py           the block between the VALUES START/END markers
    calc/fdval.py                  the same block (CRLF line endings kept)
    godot/scripts/core/values.gd   the whole file

It prints each changed value as old -> new (the old values are read from
pc/FiniteDungeons.py), then runs the edition checks: tools/edition_compare.py
and, when Godot is found, the Godot parity harness.

    python3 tools/balance.py                 # write everything, then run the checks
    python3 tools/balance.py --dry-run       # show the changes, write nothing
    python3 tools/balance.py --check         # exit 1 if any file is out of date
    python3 tools/balance.py --no-tests      # skip the checks

Godot is found from --godot, then $GODOT, then "godot" / "godot4" on PATH.

To change wording around a value (the code comments), edit the template, not
the generated file. Templates use:
    {{NAME}}  {{NAME.key}}  {{NAME.0}}    a value from balance.yaml, written
                                          in the target's syntax
    {{NAME.key|tuple}}                    a list written as (a, b, c)
    {{= expression}}                      Python expression over the values,
                                          e.g. {{= ordinal(BLESSED_EVERY)}}
    {{pad:27}}                            spaces up to column 27 (at least 1)
"""
import argparse
import ast
import difflib
import os
import re
import shutil
import subprocess
import sys

try:
    import yaml
except ImportError:
    sys.exit("tools/balance.py needs PyYAML: pip install pyyaml")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
YAML_FILE = os.path.join(ROOT, "balance.yaml")
TEMPLATES = os.path.join(ROOT, "tools", "balance_templates")
PC = "pc/FiniteDungeons.py"
START, END = "# --- VALUES START ---", "# --- VALUES END ---"

# (file, template, syntax, what the template replaces)
TARGETS = [
    (PC, "values.py.tmpl", "py", "block"),
    ("calc/fdval.py", "values.py.tmpl", "py", "block"),
    ("godot/scripts/core/values.gd", "values.gd.tmpl", "gd", "file"),
]

# Game texts say "double" for these, so another value makes the text wrong.
SAYS_DOUBLE = ["BOOK_MULTIPLIER", "DRONE_MISSILE_MULTIPLIER", "DRONE_HEAL_MULTIPLIER",
               "DRONE_INCOME_MULTIPLIER"]
# Divided or stepped by: must be above 0.
POSITIVE = ["BLESSED_EVERY", "AR_LEVEL_STEP", "COINPOT_STEP", "VITALITY_DRAIN_DIVISOR",
            "CARRIER_RELICS", "START_HP"]
README_QUOTES = {"FINAL_LEVEL": "README.md says 30 levels", "MONSTER_GROWTH": "README.md says +1 a level"}


class BalanceError(Exception):
    pass


def rel(path):
    return os.path.join(ROOT, path)


def read(path):
    with open(rel(path), encoding="utf-8", newline="") as f:
        return f.read()


# ------------------------------------------------------------------ balance.yaml

class SrcFloat(float):
    """A float that remembers how balance.yaml wrote it (0.10 stays 0.10)."""

    def __new__(cls, value, src):
        obj = float.__new__(cls, value)
        obj.src = src
        return obj


class Loader(yaml.SafeLoader):
    pass


def _float(loader, node):
    text = loader.construct_scalar(node)
    value = yaml.SafeLoader.construct_yaml_float(loader, node)
    return SrcFloat(value, text if re.fullmatch(r"-?\d+\.\d+", text) else repr(value))


def _mapping(loader, node, deep=False):
    loader.flatten_mapping(node)
    out = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=True)
        if not isinstance(key, str):
            raise BalanceError(f"balance.yaml line {key_node.start_mark.line + 1}: "
                               f"key {key!r} must be a name (quote it)")
        if key in out:
            raise BalanceError(f"balance.yaml line {key_node.start_mark.line + 1}: "
                               f"{key} appears twice")
        out[key] = loader.construct_object(value_node, deep=True)
    return out


Loader.add_constructor("tag:yaml.org,2002:float", _float)
Loader.add_constructor("tag:yaml.org,2002:map", _mapping)


def load_yaml():
    try:
        with open(YAML_FILE, encoding="utf-8") as f:
            data = yaml.load(f, Loader=Loader)
    except yaml.YAMLError as e:
        raise BalanceError(f"balance.yaml: {e}")
    if not isinstance(data, dict):
        raise BalanceError("balance.yaml must be a list of NAME: value lines")
    return data


# ------------------------------------------------------------------ current code values

def normalise(v):
    """Python literals -> balance.yaml shapes: tuples become lists, (key, n) lists dicts."""
    if isinstance(v, (list, tuple)):
        if v and all(isinstance(x, tuple) and len(x) == 2 and isinstance(x[0], str) for x in v):
            return {k: normalise(x) for k, x in v}
        return [normalise(x) for x in v]
    if isinstance(v, dict):
        return {k: normalise(x) for k, x in v.items()}
    return v


def code_values():
    """The values pc/FiniteDungeons.py plays by now."""
    text = read(PC)
    try:
        block = text[text.index(START):text.index(END)]
    except ValueError:
        raise BalanceError(f"{PC}: VALUES START/END markers not found")
    tree = ast.parse(block)
    # Floats keep their spelling (0.10, not 0.1) for the update log.
    for node in ast.walk(tree):
        if isinstance(node, ast.Constant) and type(node.value) is float:
            node.value = SrcFloat(node.value, ast.get_source_segment(block, node))
    out = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            out[node.targets[0].id] = normalise(ast.literal_eval(node.value))
    return out


def forbidden_message_count():
    for node in ast.parse(read(PC)).body:
        if (isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name)
                and node.targets[0].id == "FORBIDDEN_MESSAGES" and isinstance(node.value, ast.List)):
            return len(node.value.elts)
    return None


# ------------------------------------------------------------------ checks on the values

def same(a, b):
    """Equal values of equal types (True is not 1, 2 is not 2.0)."""
    if type(a) is not type(b) and not (isinstance(a, float) and isinstance(b, float)):
        return False
    if isinstance(a, dict):
        return list(a) == list(b) and all(same(a[k], b[k]) for k in a)
    if isinstance(a, list):
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    return a == b


def kind(v):
    if isinstance(v, bool):
        return "true/false"
    if isinstance(v, int):
        return "a whole number"
    if isinstance(v, float):
        return "a decimal (write 1.0, not 1)"
    if isinstance(v, list):
        return "a list"
    if isinstance(v, dict):
        return "a table"
    return type(v).__name__


def check_shape(new, old, path, errors):
    if isinstance(old, bool) or isinstance(new, bool):
        ok = isinstance(old, bool) and isinstance(new, bool)
    elif isinstance(old, int):
        ok = isinstance(new, int)
    elif isinstance(old, float):
        ok = isinstance(new, float)
    else:
        ok = type(new) is type(old)
    if not ok:
        errors.append(f"{path} must be {kind(old)}, not {new!r}")
        return
    if isinstance(old, list):
        if len(new) != len(old):
            errors.append(f"{path} must have {len(old)} entries (has {len(new)})")
            return
        for i, (n, o) in enumerate(zip(new, old)):
            check_shape(n, o, f"{path}[{i}]", errors)
    elif isinstance(old, dict):
        if list(new) != list(old):
            missing = [k for k in old if k not in new]
            extra = [k for k in new if k not in old]
            if missing or extra:
                errors.append(f"{path} keys are fixed by the game code: "
                              + ", ".join([f"missing {k}" for k in missing] + [f"unknown {k}" for k in extra]))
            else:
                errors.append(f"{path} keys must stay in this order: {', '.join(old)}")
            return
        for k in old:
            check_shape(new[k], old[k], f"{path}.{k}", errors)


def numbers(v):
    if isinstance(v, bool):
        return
    if isinstance(v, (int, float)):
        yield v
    elif isinstance(v, list):
        for x in v:
            yield from numbers(x)
    elif isinstance(v, dict):
        for x in v.values():
            yield from numbers(x)


def validate(data, old):
    """Errors stop the run; warnings are printed."""
    errors, warnings = [], []
    for name in old:
        if name not in data:
            errors.append(f"{name} is missing from balance.yaml")
    for name, value in data.items():
        if name in old:
            check_shape(value, old[name], name, errors)
        else:
            warnings.append(f"{name} is new: the game code must read it in every edition")
        if any(n < 0 for n in numbers(value)):
            errors.append(f"{name} has a negative number")
    if errors:
        return errors, warnings
    g = data.get
    if not 1 <= g("FINAL_LEVEL", 30) <= 31:
        errors.append("FINAL_LEVEL must be 1-31 (save codes store at most 31)")
    if g("DRONE_STAGES", 4) != 4:
        errors.append("DRONE_STAGES must stay 4: the drone's texts describe 4 stages")
    for name in POSITIVE:
        if name in data and data[name] <= 0:
            errors.append(f"{name} must be above 0")
    if "VITALITY_MONEY_LOSS" in data and not 0 <= data["VITALITY_MONEY_LOSS"] <= 1:
        errors.append("VITALITY_MONEY_LOSS is a share of your money: 0.0 to 1.0")
    for key, rgb in g("TEXT_COLOURS", {}).items():
        if any(c > 255 for c in rgb):
            errors.append(f"TEXT_COLOURS.{key} values must be 0-255")
    for name in SAYS_DOUBLE:
        if name in data and data[name] != 2:
            warnings.append(f"{name} is {data[name]}, but game texts call it \"double\": "
                            f"reword them in every edition")
    if g("AR_POWER", 4) not in (2, 3, 4):
        warnings.append(f"AR_POWER {data['AR_POWER']} has no superscript sign: the PC shows "
                        f"^{data['AR_POWER']}; check AR_POWER_SIGN in every edition and the Godot fonts")
    count = forbidden_message_count()
    if count is not None and g("LIMIT", {}).get("ink", 0) > count:
        warnings.append(f"LIMIT.ink is {data['LIMIT']['ink']} but there are only {count} "
                        f"FORBIDDEN_MESSAGES: later inks repeat the last one")
    return errors, warnings


# ------------------------------------------------------------------ rendering

def lit(v, syntax, as_tuple=False):
    """A value written in the target's syntax."""
    if isinstance(v, bool):
        return ("True" if v else "False") if syntax == "py" else ("true" if v else "false")
    if isinstance(v, SrcFloat):
        return v.src
    if isinstance(v, (int, float, str)):
        return str(v) if not isinstance(v, float) else repr(v)
    if isinstance(v, list):
        inner = ", ".join(lit(x, syntax) for x in v)
        return f"({inner})" if as_tuple else f"[{inner}]"
    raise BalanceError(f"can't write {v!r} into a template")


def cumsum(xs):
    out, total = [], 0
    for x in xs:
        total += x
        out.append(total)
    return out


def ordinal(n):
    suffix = "th" if 10 <= n % 100 <= 20 else {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
    return f"{n}{suffix}"


HELPERS = {"cumsum": cumsum, "ordinal": ordinal, "len": len, "sum": sum, "str": str,
           "map": map, "min": min, "max": max, "int": int, "round": round, "list": list}
TOKEN = re.compile(r"\{\{(.*?)\}\}")


def lookup(ctx, path):
    v = ctx
    for part in path.split("."):
        if isinstance(v, dict) and part in v:
            v = v[part]
        elif isinstance(v, list) and part.isdigit() and int(part) < len(v):
            v = v[int(part)]
        else:
            raise KeyError(path)
    return v


def render(template_name, ctx, syntax, used):
    """Fill one template. `used` collects every value path it writes."""
    with open(os.path.join(TEMPLATES, template_name), encoding="utf-8", newline="") as f:
        template = f.read()
    names = {k: v for k, v in ctx.items() if k.isidentifier()}
    lines = []
    for n, line in enumerate(template.split("\n"), 1):
        out, pos = "", 0
        for m in TOKEN.finditer(line):
            out += line[pos:m.start()]
            pos = m.end()
            tok = m.group(1).strip()
            where = f"{template_name} line {n}: {{{{{tok}}}}}"
            try:
                if tok.startswith("pad:"):
                    out += " " * max(1, int(tok[4:]) - len(out))
                elif tok.startswith("="):
                    v = eval(tok[1:], {"__builtins__": {}}, {**HELPERS, **names})
                    out += v if isinstance(v, str) else lit(v, syntax)
                else:
                    path, _, filt = tok.partition("|")
                    v = lookup(ctx, path.strip())
                    out += v if isinstance(v, str) else lit(v, syntax, filt.strip() == "tuple")
                    used.add(path.strip())
            except KeyError as e:
                raise BalanceError(f"{where}: no value {e} in balance.yaml")
            except BalanceError:
                raise
            except Exception as e:
                raise BalanceError(f"{where}: {type(e).__name__}: {e}")
        lines.append(out + line[pos:])
    return "\n".join(lines)


def leaves(v, path):
    if isinstance(v, dict):
        for k, x in v.items():
            yield from leaves(x, f"{path}.{k}")
    elif isinstance(v, list):
        for i, x in enumerate(v):
            yield from leaves(x, f"{path}.{i}")
    else:
        yield path


def covered(leaf, used):
    return any(leaf == u or leaf.startswith(u + ".") for u in used)


# ------------------------------------------------------------------ change summary

def describe_changes(old, new):
    """One line per changed name, old -> new."""
    def f(v, name=""):
        return lit(v, "text", as_tuple=(name == "TEXT_COLOURS" and isinstance(v, list)))

    out = []
    for name, n in new.items():
        if name not in old:
            out.append(f"{name} added: {f(n, name)}")
            continue
        o = old[name]
        if same(o, n):
            continue
        if name == "DRONE_STAGE_COSTS":
            parts = [f"track {t + 1} stage {s + 1}: {a} -> {b}"
                     for t, (ra, rb) in enumerate(zip(o, n)) for s, (a, b) in enumerate(zip(ra, rb)) if a != b]
            out.append(f"{name}, " + ", ".join(parts))
        elif isinstance(n, dict) and name.endswith("_UNLOCKS"):
            parts = [f"{k} {f(o[k])} -> {f(n[k])}" for k in n if not same(o[k], n[k])]
            out.append(f"{name}: " + ", ".join(parts))
        elif isinstance(n, dict):
            parts = [f'{name}["{k}"] {f(o[k], name)} -> {f(n[k], name)}' for k in n if not same(o[k], n[k])]
            out.append(", ".join(parts))
        else:
            out.append(f"{name} {f(o)} -> {f(n)}")
    for name in old:
        if name not in new:
            out.append(f"{name} removed")
    return out


# ------------------------------------------------------------------ outputs

def build(data):
    """{file: new full text}, plus a coverage check of every template."""
    ctx = dict(data)
    outputs, rendered, missing = {}, {}, []
    for path, template, syntax, mode in TARGETS:
        if template not in rendered:
            used = set()
            text = render(template, ctx, syntax, used)
            rendered[template] = text
            for name, value in data.items():
                for leaf in leaves(value, name):
                    if not covered(leaf, used):
                        missing.append(f"{template} never writes {leaf}")
        text = rendered[template]
        current = read(path)
        if mode == "block":
            try:
                s, e = current.index(START), current.index(END) + len(END)
            except ValueError:
                raise BalanceError(f"{path}: VALUES START/END markers not found")
            block = text.rstrip("\n")
            if "\r\n" in current:
                block = block.replace("\n", "\r\n")
            outputs[path] = current[:s] + block + current[e:]
        else:
            if "\r\n" in current:
                text = text.replace("\r\n", "\n").replace("\n", "\r\n")
            outputs[path] = text
    if missing:
        raise BalanceError("templates must write every value:\n  " + "\n  ".join(missing))
    return outputs


def show_diff(path, old, new):
    diff = difflib.unified_diff(old.replace("\r\n", "\n").split("\n"), new.replace("\r\n", "\n").split("\n"),
                                f"a/{path}", f"b/{path}", lineterm="", n=1)
    print("\n".join(diff))


# ------------------------------------------------------------------ checks after writing

def find_godot(arg):
    for cand in (arg, os.environ.get("GODOT"), shutil.which("godot"), shutil.which("godot4")):
        if cand and os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    return None


def run_checks(seeds, godot_arg):
    ok = True
    pc, calc = read(PC), read("calc/fdval.py").replace("\r\n", "\n")
    if pc[pc.index(START):pc.index(END)] != calc[calc.index(START):calc.index(END)]:
        print("FAIL  VALUES blocks differ between pc/ and calc/")
        ok = False
    else:
        print("ok    VALUES blocks identical in pc/ and calc/")

    print(f"...   tools/edition_compare.py --seeds {seeds}")
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "edition_compare.py"),
                        "--seeds", str(seeds)], cwd=ROOT, capture_output=True, text=True)
    out = (r.stdout + r.stderr).strip()
    print(("ok    " if r.returncode == 0 else "FAIL  ") + (out.splitlines()[-1] if out else ""))
    if r.returncode != 0:
        print(out[-3000:])
        ok = False

    godot = find_godot(godot_arg)
    if not godot:
        print("skip  Godot parity: no Godot found (pass --godot or set $GODOT)")
        return ok
    gdir = os.path.join(ROOT, "godot")
    env = dict(os.environ, GODOT=godot)
    if not os.path.isdir(os.path.join(gdir, ".godot", "imported")):
        # A fresh checkout's first import leaves fonts unimported; the parity run imports again.
        print("...   first Godot import (no godot/.godot yet)")
        subprocess.run([godot, "--headless", "--path", gdir, "--import"], capture_output=True)
    print("...   Godot parity (godot/tests/parity/run_parity.sh)")
    r = subprocess.run([os.path.join(gdir, "tests", "parity", "run_parity.sh")], cwd=gdir, env=env,
                       capture_output=True, text=True)
    out = (r.stdout + r.stderr).strip()
    print(("ok    " if r.returncode == 0 else "FAIL  ") + (out.splitlines()[-1] if out else ""))
    if r.returncode != 0:
        print(out[-3000:])
        ok = False
    return ok


# ------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true", help="exit 1 if any file is out of date; write nothing")
    ap.add_argument("--dry-run", action="store_true", help="print the changes; write nothing")
    ap.add_argument("--no-tests", action="store_true", help="skip the checks after writing")
    ap.add_argument("--seeds", type=int, default=1000, help="edition_compare.py walks (default 1000)")
    ap.add_argument("--godot", help="Godot executable for the parity check")
    args = ap.parse_args()

    try:
        data = load_yaml()
        old = code_values()
        errors, warnings = validate(data, old)
        if errors:
            print("balance.yaml has problems, nothing written:")
            for e in errors:
                print("  " + e)
            return 2
        changes = describe_changes(old, data)
        outputs = build(data)
    except BalanceError as e:
        print(f"error: {e}")
        return 2

    stale = [p for p, text in outputs.items() if read(p) != text]

    if args.check:
        if not stale:
            print("Up to date: every edition matches balance.yaml.")
            return 0
        print("Out of date with balance.yaml (run python3 tools/balance.py):")
        for p in stale:
            print("  " + p)
        for c in changes:
            print("  changed: " + c)
        return 1

    for w in warnings:
        print("warning: " + w)
    if not stale:
        print("Nothing to do: every edition already matches balance.yaml.")
        return 0

    if changes:
        print("Changed values:")
        for c in changes:
            print("  " + c)
        for name, why in README_QUOTES.items():
            if name in old and name in data and not same(old[name], data[name]):
                print(f"warning: {name} changed and {why}: update it by hand")
        print("warning: strats/ was written for an older balance: re-check the route with tools/route_search.py")
    else:
        print("No value changed; rewriting files from the templates.")

    if args.dry_run:
        for p in stale:
            show_diff(p, read(p), outputs[p])
        print("\nDry run: nothing written.")
        return 0

    for p in stale:
        with open(rel(p), "w", encoding="utf-8", newline="") as f:
            f.write(outputs[p])
        print("wrote " + p)

    if args.no_tests:
        return 0
    print()
    if run_checks(args.seeds, args.godot):
        print("\nAll checks passed.")
        return 0
    print("\nChecks FAILED. The files are written; fix the cause or revert them with git.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
