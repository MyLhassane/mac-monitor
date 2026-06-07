# Configuration Guide

All configuration lives in `modules/config.py`. Changes take effect immediately on next launch — no build step or compilation.

## Constants

```python
class Config:
    DB_DIR = Path.home() / ".mac-monitor-groq"
    DB_PATH = DB_DIR / "process_cache.db"
    GROQ_MODEL = "llama-3.1-8b-instant"
    GROQ_MAX_CONCURRENT = 5
    GROQ_DELAY_BETWEEN = 0.4
    GROQ_MAX_RETRIES = 2
    SNAPSHOT_MAX_PER_CATEGORY = 50
    UI_REFRESH_INTERVAL = 0.5
    WHATIS_TIMEOUT = 10
```

### `DB_DIR` / `DB_PATH`
The SQLite database location. Defaults to `~/.mac-monitor-groq/process_cache.db`. Change this to use a project-local database instead:
```python
DB_DIR = Path(".")  # creates cache.db in current directory
```

### `GROQ_MODEL`
The Groq model to use for generating descriptions.

| Model | Speed | Quality | Free tier limits |
|-------|-------|---------|------------------|
| `llama-3.1-8b-instant` | ⚡ Fastest | Good | 14,400 req/day, 500K tok/day |
| `llama-3.3-70b-versatile` | Fast | Better | 1,000 req/day, 100K tok/day |
| `qwen/qwen3-32b` | Fast | Better | 60 RPM, 1,000 req/day |

Trade-off: the 8B model handles 14,400 requests/day but occasionally hallucinates (e.g., confusing Code Helper with Xcode). The 70B model is more accurate but limited to 1,000 requests/day.

### `GROQ_DELAY_BETWEEN`
Minimum seconds between Groq API calls. Controls the rate limit:
- `0.4` = 150 req/min (may hit Groq's 30 RPM limit)
- `2.0` = 30 req/min (safe, compliant with free tier)
- `0.0` = fire as fast as possible (will get 429 errors)

### `GROQ_MAX_CONCURRENT`
Currently unused (background resolver processes sequentially). Reserved for future parallel implementation.

### `SNAPSHOT_MAX_PER_CATEGORY`
How many processes to display per category. Default: 50 per section = 150 total. Reduce to 10-20 for a compact view:
```python
SNAPSHOT_MAX_PER_CATEGORY = 15  # show only top 15 per section
```

### `WHATIS_TIMEOUT`
Maximum seconds to wait for a single `whatis` call. Default: 10 seconds. Some daemon names with many man page matches (like `launchd`) can take 8+ seconds. Increase to 30 for very slow machines, or decrease to 3 if you find the wait unacceptable:
```python
WHATIS_TIMEOUT = 3  # skip whatis if it takes longer than 3s
```

### `UI_REFRESH_INTERVAL`
Currently not directly used (the main loop uses `select.select` with 0.3s timeout). Reserved for future auto-refresh functionality.

## HARDCODED_OVERRIDES

A dictionary that fixes known AI hallucinations. Add entries here when you notice a process consistently getting a wrong description from Groq.

```python
HARDCODED_OVERRIDES = {
    "Code Helper": "VS Code extension host process",
    "opencode": "AI-powered CLI coding assistant",
    "context7-mcp": "AI context provider MCP server",
    ...
}
```

**Adding a new override:**
1. Run the monitor and identify a process with a wrong description
2. Add an entry: `"process_name": "correct description"`
3. Re-run the monitor — the override takes effect immediately

**Note**: Overrides also apply to the classification system. If a process needs a different category, add it to `KNOWN_CLASSES` instead.

## KNOWN_CLASSES

A dictionary that overrides the classifier for specific processes.

```python
KNOWN_CLASSES = {
    "kernel_task": "SYSTEM_CORE",
    "launchd": "SYSTEM_CORE",
    "WindowServer": "SYSTEM_CORE",
    ...
    "configd": "BACKGROUND_SERVICE",
    "amfid": "BACKGROUND_SERVICE",
}
```

**When to add to KNOWN_CLASSES vs letting the rules handle it:**

| Scenario | Action |
|----------|--------|
| A daemon is misclassified as USER_APP | Add to KNOWN_CLASSES with your category |
| A user app is misclassified as SYSTEM_CORE | Add to KNOWN_CLASSES with `USER_APP` |
| You're unsure of the classification | Let the rules handle it; check the displayed category |

**Why not classify everything in KNOWN_CLASSES?**  
The dictionary covers ~20 of the most common processes. Full coverage would be impractical (300+ unique processes on a typical system). The rule engine handles the rest with reasonable accuracy.

## Groq API system prompt

The system prompt sent to Groq is hardcoded in `groq_provider.py`:

```python
"content": "You are a macOS expert. Provide a short technical description "
           "(5-8 words) for the given macOS process name. "
           "No markdown, no quotes, no punctuation at end.",
```

**Customizing the prompt**: Edit this string to change the tone, style, or format of descriptions:

```python
# Example: more detailed descriptions
"content": "Describe the macOS process '{name}' in exactly 10 words. Be specific about its role."

# Example: casual tone
"content": "Explain what this macOS process does in simple terms, max 8 words."

# Example: Arabic descriptions
"content": "اشرح عملية macOS هذه بوصف تقني مختصر (5-8 كلمات)."
```

Note: changing the prompt invalidates the cache — old descriptions were generated with the old prompt. Delete `~/.mac-monitor-groq/process_cache.db` to force re-generation.

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GROQ_API_KEY` | Yes (for AI mode) | Your Groq API key from console.groq.com |

The key can be set via:
1. `.env` file in the project root (loaded by `python-dotenv`)
2. Environment variable: `export GROQ_API_KEY="gsk_..."`
3. Both — `.env` takes precedence if present

## Sanity check: verifying your config

```bash
# Test that the module loads without errors
python3 -c "from modules import Config; print('OK:', Config.DB_PATH)"

# Test with a specific override
python3 -c "
from modules import ProcessCache, DescriptionResolver
r = DescriptionResolver()
desc, cat, src = r.resolve_immediate('Code Helper', '/dummy/path', 'USER_APP')
print(f'{src}: {desc}')
"
```
