
```python
import sqlite3
from datetime import datetime
from .config import Config


class ProcessCache:
    def __init__(self):
        Config.ensure_db_dir()
        self._init_db()

    def _init_db(self):
        conn = sqlite3.connect(str(Config.DB_PATH))
        c = conn.cursor()
        c.execute("""
            CREATE TABLE IF NOT EXISTS process_cache (
                name        TEXT PRIMARY KEY,
                description TEXT,
                category    TEXT,
                source      TEXT,
                first_seen  TEXT,
                last_seen   TEXT,
                times_seen  INTEGER DEFAULT 1
            )
        """)
        conn.commit()
        conn.close()

    def get(self, name):
        conn = sqlite3.connect(str(Config.DB_PATH))
        c = conn.cursor()
        c.execute(
            "SELECT description, category, source FROM process_cache WHERE name = ?",
            (name,),
        )
        row = c.fetchone()
        conn.close()
        if row:
            return {"description": row[0], "category": row[1], "source": row[2]}
        return None

    def set(self, name, description, category, source):
        now = datetime.now().isoformat()
        conn = sqlite3.connect(str(Config.DB_PATH))
        c = conn.cursor()
        c.execute(
            """INSERT INTO process_cache (name, description, category, source, first_seen, last_seen, times_seen)
               VALUES (?, ?, ?, ?, ?, ?, 1)
               ON CONFLICT(name) DO UPDATE SET
                   description = excluded.description,
                   category = excluded.category,
                   source = excluded.source,
                   last_seen = excluded.last_seen,
                   times_seen = times_seen + 1""",
            (name, description, category, source, now, now),
        )
        conn.commit()
        conn.close()
```
