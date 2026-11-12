// Minimal D1 stand-in on node:sqlite, with every migration applied, for route tests.
import { DatabaseSync } from 'node:sqlite';
import { readdirSync, readFileSync } from 'node:fs';

export function makeDb() {
  const db = new DatabaseSync(':memory:');
  const dir = new URL('../migrations/', import.meta.url);
  for (const f of readdirSync(dir).filter((f) => f.endsWith('.sql')).sort()) db.exec(readFileSync(new URL(f, dir), 'utf8'));
  const stmt = (sql, args = []) => ({
    bind: (...a) => stmt(sql, a),
    all: async () => ({ results: db.prepare(sql).all(...args) }),
    first: async () => db.prepare(sql).get(...args) ?? null,
    run: async () => { const r = db.prepare(sql).run(...args); return { meta: { changes: r.changes } }; },
    _run: () => (/^\s*(select|with)/i.test(sql) ? { results: db.prepare(sql).all(...args) } : (db.prepare(sql).run(...args), { results: [] })),
  });
  return { raw: db, prepare: (sql) => stmt(sql), batch: async (list) => list.map((s) => s._run()) };
}
