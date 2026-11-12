"""D1 rejects SQL statements over 100 KB. Long text values (photos, document parts, signatures)
are inserted empty, then filled with UPDATE ... SET col = col || 'piece' in 40 KB pieces."""
import re, sys

LIMIT = 90_000
PIECE = 40_000

def tokens(values):
    out, i, n = [], 0, len(values)
    while i < n:
        c = values[i]
        if c in ' ,\n':
            i += 1
        elif c == "'":
            j, buf = i + 1, []
            while True:
                k = values.index("'", j)
                buf.append(values[j:k])
                if k + 1 < n and values[k + 1] == "'":
                    buf.append("'")
                    j = k + 2
                else:
                    i = k + 1
                    break
            out.append(("s", "".join(buf)))
        else:
            m = re.match(r"[^,]+", values[i:])
            out.append(("r", m.group(0).strip()))
            i += m.end()
    return out

def q(s):
    return "'" + s.replace("'", "''") + "'"

src, dst = sys.argv[1], sys.argv[2]
pat = re.compile(r'^INSERT INTO ("?[\w]+"?) ?\(([^)]*)\) ?VALUES ?\((.*)\);\s*$', re.S)
split = 0
with open(src) as f, open(dst, "w") as o:
    for line in f:
        if len(line) <= LIMIT:
            o.write(line)
            continue
        m = pat.match(line)
        if not m:
            sys.exit("cannot split a long line: " + line[:120])
        table, cols = m.group(1), [c.strip() for c in m.group(2).split(",")]
        vals = tokens(m.group(3))
        assert len(vals) == len(cols), (table, len(vals), len(cols))
        long_ = [i for i, (k, v) in enumerate(vals) if k == "s" and len(v) > PIECE]
        first = [q("") if i in long_ else (q(v) if k == "s" else v) for i, (k, v) in enumerate(vals)]
        o.write(f"INSERT INTO {table} ({','.join(cols)}) VALUES({','.join(first)});\n")
        where = " AND ".join(
            f"{cols[i]} IS NULL" if (k == "r" and v.upper() == "NULL") else f"{cols[i]} = {q(v) if k == 's' else v}"
            for i, (k, v) in enumerate(vals) if i not in long_)
        for i in long_:
            v = vals[i][1]
            for p in range(0, len(v), PIECE):
                o.write(f"UPDATE {table} SET {cols[i]} = {cols[i]} || {q(v[p:p + PIECE])} WHERE {where};\n")
        split += 1
print(f"split {split} long rows")
