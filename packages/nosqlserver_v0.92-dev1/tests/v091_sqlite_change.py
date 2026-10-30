#!/usr/bin/env python3
"""Independent SQLite connection used to force post-snapshot phantoms."""
import sqlite3, sys
_, action, path, key, value = sys.argv
with sqlite3.connect(path, timeout=5) as db:
    if action == 'add':
        db.execute('INSERT INTO notes (id, body) VALUES (?, ?)', (int(key), value))
    elif action == 'edit':
        db.execute('UPDATE notes SET body=? WHERE id=?', (value, int(key)))
    else:
        raise SystemExit('unknown action')
