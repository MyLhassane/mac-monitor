# SQLite Caching System

The cache prevents repeated API calls and slow whatis lookups across sessions. It's a single-table SQLite database stored at `~/.mac-monitor-groq/process_cache.db`.

## Schema

```sql
CREATE TABLE process_cache (
    name        TEXT PRIMARY KEY,  -- process name (e.g., "WindowServer")
    description TEXT,              -- plain-text description
    category    TEXT,              -- USER_APP / BACKGROUND_SERVICE / SYSTEM_CORE
    source      TEXT,              -- cache / hardcoded / whatis / path / groq / fallback
    first_seen  TEXT,              -- ISO8601 timestamp of first appearance
    last_seen   TEXT,              -- ISO8601 timestamp of most recent appearance
    times_seen  INTEGER DEFAULT 1 -- how many times this process has been captured
);
```

### Column rationale

**`name` as PRIMARY KEY**: Process names are unique identifiers across the system. Two different executables won't have the same basename — if they did, they'd be indistinguishable in `ps` output anyway.

**`description`**: Stores the output of whatever engine resolved it (cache, hardcoded, whatis, path, groq, or fallback). No normalization is performed — what you see is what was resolved.

**`category`**: Stored alongside the description so the tool doesn't need to re-classify cached processes. This also allows manual overrides: if you change a process's category in `KNOWN_CLASSES`, the cache will reflect it.

**`source`**: Tracks which engine produced the description. This is used by `resolve_immediate` to decide whether to trust a cached value. Currently only `source != "groq"` is checked (we always re-resolve groq descriptions each session since they're from a cloud API and might have changed). This heuristic could be refined.

**`first_seen / last_seen / times_seen`**: Usage metrics that enable:
- Identifying which processes are persistent vs transient
- Potentially expiring rarely-seen entries (not implemented)
- Debugging what's running on a system over time

## The `set()` method — upsert semantics

```python
def set(self, name, description, category, source):
    now = datetime.now().isoformat()
    conn = sqlite3.connect(str(Config.DB_PATH))
    c = conn.cursor()
    c.execute("""
        INSERT INTO process_cache (name, description, category, source, first_seen, last_seen, times_seen)
        VALUES (?, ?, ?, ?, ?, ?, 1)
        ON CONFLICT(name) DO UPDATE SET
            description = excluded.description,
            category = excluded.category,
            source = excluded.source,
            last_seen = excluded.last_seen,
            times_seen = times_seen + 1
    """, (name, description, category, source, now, now))
    conn.commit()
    conn.close()
```

This uses SQLite's `ON CONFLICT ... DO UPDATE` (UPSERT) syntax, supported since SQLite 3.24.0 (2018). On first insert:
- `first_seen` = current time
- `times_seen` = 1

On subsequent updates:
- `description`, `category`, `source` are overwritten
- `last_seen` is updated
- `times_seen` is incremented

This means a process that appears across many sessions builds up a `times_seen` count, which is useful for understanding whether something is a persistent daemon or a one-off script.

## The `get()` method

```python
def get(self, name):
    c.execute("SELECT description, category, source FROM process_cache WHERE name = ?", (name,))
    row = c.fetchone()
    if row:
        return {"description": row[0], "category": row[1], "source": row[2]}
    return None
```

Returns a dict with three fields, or `None` if the process name isn't in the cache. The caller (`resolve_immediate`) uses the `source` field to decide how much to trust the value:

```python
cached = self.cache.get(name)
if cached and cached["source"] != "groq":
    return cached["description"], category, cached["source"]
```

**Why skip groq-sourced cache entries?**  
The idea is that Groq descriptions might improve over time (model updates, better prompts). By re-resolving groq entries each session, the tool can pick up improvements. Cache/whatis/path descriptions are deterministic and won't change.

**Consequence**: On every session, previously groq-resolved processes will briefly show "⏳ Resolving..." in the first render, then get their cached description back. This creates a slight flicker for ~350 processes on the second run.

**Potential improvement**: Add a "staleness" check — only re-resolve groq entries older than N days. This would make the second-run experience fully instant.

## Database location

```python
DB_DIR = Path.home() / ".mac-monitor-groq"
DB_PATH = DB_DIR / "process_cache.db"
```

The database lives in the user's home directory (not the project folder) so that:
1. It persists across project updates (git pull won't delete it)
2. Multiple copies of the tool share the same cache
3. The user can delete it safely without affecting the code

## Manual inspection

```bash
# See all cached descriptions
sqlite3 ~/.mac-monitor-groq/process_cache.db "SELECT name, source, substr(description,1,40) FROM process_cache ORDER BY times_seen DESC LIMIT 20;"

# Count by source
sqlite3 ~/.mac-monitor-groq/process_cache.db "SELECT source, COUNT(*) FROM process_cache GROUP BY source;"

# Find processes with highest times_seen
sqlite3 ~/.mac-monitor-groq/process_cache.db "SELECT name, times_seen FROM process_cache ORDER BY times_seen DESC LIMIT 10;"

# Clear the cache
rm ~/.mac-monitor-groq/process_cache.db
```

## Cache sizing

| Metric | Typical value |
|--------|---------------|
| Total entries | 300-600 |
| Average description length | 36 characters |
| Database size | ~40-80 KB |
| Growth rate | ~10 new entries per day |

SQLite handles this scale effortlessly. No VACUUM or maintenance needed.
