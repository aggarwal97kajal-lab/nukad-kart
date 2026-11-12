"""One-off code mod: wraps human-readable string literals in tr('template', [args]) and removes `const`
where an expression now reads a theme colour or a translation. Prints the templates found (for l10n.dart)."""
import json, pathlib, re, sys

PALETTE = ["kInk", "kAct", "kOnAct", "kBg", "kCard", "kSurf", "kLine", "kMute", "kRed", "kRedBg", "kRedLine", "kAmb",
           "kAmbBg", "kAmbLine", "kOkBg", "kLocked", "kLockedLine", "kHeader", "kOnHeader", "gDark"]
DYN = re.compile(r"\b(" + "|".join(PALETTE) + r")\b|\btr\(|\bt\(")
SKIP_FILES = {"l10n.dart", "keys.dart", "ola.dart", "push.dart", "upi.dart", "session.dart", "agreement_pdf.dart",
              "prefs.dart", "ui.dart", "pass_active.dart"}


def scan(src):
    """Yields (kind, start, end) for strings and comments in Dart source. Strings: top-level only."""
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if src.startswith("/*", i):
            j = src.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        if c in "'\"":
            raw = i > 0 and src[i - 1] == "r" and not (src[i - 2].isalnum() if i > 1 else False)
            start = i - 1 if raw else i
            end = string_end(src, i, raw)
            yield ("str", start, end)
            i = end
            continue
        i += 1


def string_end(src, i, raw):
    q = src[i]
    triple = src.startswith(q * 3, i)
    delim = q * 3 if triple else q
    j = i + len(delim)
    n = len(src)
    while j < n:
        if not raw and src[j] == "\\":
            j += 2
            continue
        if src.startswith(delim, j):
            return j + len(delim)
        if not raw and src.startswith("${", j):
            depth, k = 1, j + 2
            while k < n and depth:
                if src[k] in "'\"":
                    k = string_end(src, k, False)
                    continue
                if src[k] == "{":
                    depth += 1
                elif src[k] == "}":
                    depth -= 1
                k += 1
            j = k
            continue
        j += 1
    return n


def template(lit):
    """'Pay ₹${p['price']} with $name' -> ('Pay ₹{0} with {1}', ["p['price']", 'name']) or None if raw/triple."""
    if lit.startswith("r") or lit[:3] in ("'''", '"""'):
        return None
    q = lit[0]
    body = lit[1:-1]
    out, args, j = [], [], 0
    while j < len(body):
        ch = body[j]
        if ch == "\\":
            out.append(body[j:j + 2]); j += 2; continue
        if body.startswith("${", j):
            depth, k = 1, j + 2
            while k < len(body) and depth:
                if body[k] in "'\"":
                    k = string_end(body, k, False); continue
                if body[k] == "{": depth += 1
                elif body[k] == "}": depth -= 1
                k += 1
            args.append(body[j + 2:k - 1]); out.append("{%d}" % (len(args) - 1)); j = k; continue
        if ch == "$":
            m = re.match(r"\$([A-Za-z_]\w*)", body[j:])
            if m:
                args.append(m.group(1)); out.append("{%d}" % (len(args) - 1)); j += m.end(); continue
        out.append(ch); j += 1
    return q, "".join(out), args


def human(tmpl):
    t = re.sub(r"\{\d+\}", "", tmpl).strip()
    if len(t) < 2 or not re.search(r"[A-Za-z]", t):
        return False
    if t.startswith(("/", "http", "assets/", "upi:", "package:", "dart:")) or "://" in t:
        return False
    if re.fullmatch(r"[a-z_][\w.\-]*", t):  # keys, codes, field names
        return False
    if re.fullmatch(r"[A-Z0-9_\-]+", t):  # PAID, POST…
        return False
    if re.fullmatch(r"[\w.\-]+@[\w.\-]+", t) or re.fullmatch(r"[\w\-]+\.(jpg|pdf|png|txt|xlsx|csv)", t):
        return False
    if " " not in t and not t[0].isupper() and not t.endswith(("…", "!", ".")):
        return False
    return True


def context_ok(src, s, e):
    line = src[src.rfind("\n", 0, s) + 1:src.find("\n", e)]
    if "'Jan'" in line or "'am'" in line:
        return False
    before = src[max(0, s - 40):s].rstrip()
    after = src[e:e + 6].lstrip()
    if before.endswith(("[", "==", "!=", "case", "import", "export", "part", "@pragma(", "RegExp(", "Uri.parse(",
                        "Image.asset(", "loadString(", "getString(", "setString(", "remove(", "Key(",
                        "fontFamily:", "family:")):
        return False
    if after.startswith(("=>", ":", "]")) and not after.startswith("::"):
        # map keys / switch patterns, but allow ternary "a ? 'x' : 'y'" (preceded by ?)
        if not before.endswith("?"):
            return False
    if re.search(r"(?<![\w.])(t|tr)\($", before):
        return False
    if re.search(r"api\.(call|bytes|putBytes)\($", before) or re.search(r"api\.call\('[A-Z]+',\s*$", before):
        return False
    return True


def wrap_file(path, found):
    src = path.read_text()
    edits = []
    for kind, s, e in scan(src):
        lit = src[s:e]
        tp = template(lit)
        if not tp:
            continue
        q, tmpl, args = tp
        if not human(tmpl) or not context_ok(src, s, e):
            continue
        key = tmpl
        found.add(key)
        literal = q + tmpl + q
        rep = f"tr({literal})" if not args else f"tr({literal}, [{', '.join(args)}])"
        edits.append((s, e, rep))
    for s, e, rep in reversed(edits):
        src = src[:s] + rep + src[e:]
    return src


def extent(src, i):
    """End of the expression that starts at i (after `const `)."""
    n = len(src)
    m = re.match(r"[A-Za-z_][\w.]*", src[i:])
    j = i + (m.end() if m else 0)
    if j < n and src[j] == "<":
        depth = 0
        while j < n:
            if src[j] == "<": depth += 1
            elif src[j] == ">":
                depth -= 1
                if depth == 0: j += 1; break
            j += 1
    if j < n and src[j] in "([{":
        open_, close = src[j], {"(": ")", "[": "]", "{": "}"}[src[j]]
        depth = 0
        while j < n:
            if src[j] in "'\"":
                j = string_end(src, j, False); continue
            if src[j] == open_: depth += 1
            elif src[j] == close:
                depth -= 1
                if depth == 0: return j + 1
            j += 1
    return j


def unconst(src):
    out = []
    for m in re.finditer(r"\bconst\s+", src):
        s = m.start()
        # skip inside strings/comments
        out.append(m)
    # mask strings/comments
    mask = [False] * len(src)
    for kind, s, e in scan(src):
        for k in range(s, e): mask[k] = True
    # comments
    for cm in re.finditer(r"//[^\n]*", src):
        pass
    edits = []
    for m in out:
        s = m.start()
        if mask[s]:
            continue
        decl = re.match(r"const\s+([A-Za-z_]\w*)\s*=", src[s:])
        if decl:
            semi = src.find(";", s)
            if DYN.search(src[s:semi]):
                edits.append((s, s + 5, "final"))
            continue
        e = extent(src, m.end())
        if DYN.search(src[m.end():e]):
            edits.append((s, m.end(), ""))
    for s, e, rep in sorted(edits, reverse=True):
        src = src[:s] + rep + src[e:]
    return src


if __name__ == "__main__":
    root = pathlib.Path("lib")
    found = set()
    for f in sorted(root.rglob("*.dart")):
        if f.name in SKIP_FILES:
            continue
        new = wrap_file(f, found)
        if "tr(" in new and "ui.dart" not in new and f.name != "ui.dart":
            pass
        f.write_text(new)
    for f in sorted(root.rglob("*.dart")):
        if f.name in ("l10n.dart",):
            continue
        f.write_text(unconst(f.read_text()))
    json.dump(sorted(found), open("/tmp/i18n_keys.json", "w"), ensure_ascii=False, indent=0)
    print(len(found), "templates")
