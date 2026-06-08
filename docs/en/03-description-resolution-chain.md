# Description Resolution Chain

The core challenge this tool solves: **how to provide a meaningful plain-English description for every running process on macOS, with zero setup cost and high reliability.**

The answer is a 6-level fallback chain. Each level is a different "engine" with different trade-offs:

| Level | Engine | Speed | Network | Quality | Hit rate (est.) |
|-------|--------|-------|---------|---------|-----------------|
| 1 | SQLite Cache | <1ms | No | Preserves best available | 80%+ on 2nd run |
| 2 | Hardcoded Overrides | <1ms | No | Manual curated | ~2% |
| 3 | Path Extraction | <1ms | No | Vague but accurate | ~20% |
| 4 | Whatis | 2-10s | No | Accurate for daemons | ~15% |
| 5 | Groq AI | 0.5s | Yes | High quality | ~60% |
| 6 | Generic Fallback | <1ms | No | "macOS process: {name}" | ~3% |

The chain is evaluated in `DescriptionResolver` (`modules/descriptions.py`). Levels 1-3 are **immediate** (blocking, called from the main thread before first render). Levels 4-6 are **background** (called from the daemon thread).

## Level 1: SQLite Cache

```python
cached = self.cache.get(name)
if cached:
    return cached["description"], category, cached["source"]
```

On every launch, the tool first checks `~/.mac-monitor-groq/process_cache.db`. If a process was described in a previous session, the description is returned instantly regardless of which engine produced it originally.

**Why cache everything, not just AI responses?**  
Because whatis is slow (2-10 seconds per call). Once a whatis result is obtained, caching it saves 2-10 seconds on every subsequent launch.

**Cache invalidation**: The cache is **write-only**. There's no TTL or eviction. The reasoning: process names don't change (no macOS daemon called `configd` will suddenly do something different). If you want to clear the cache, delete the database file.

## Level 2: Hardcoded Overrides

```python
if name in Config.HARDCODED_OVERRIDES:
    desc = Config.HARDCODED_OVERRIDES[name]
    self.cache.set(name, desc, category, "hardcoded")
    return desc, category, "hardcoded"
```

A small dictionary in `config.py` that fixes known AI **hallucinations**. During testing with Groq, some process names consistently produced wrong descriptions:

| Process Name | Groq gave | Override |
|-------------|-----------|----------|
| `Code Helper` | "Xcode debugging assistant" | "VS Code extension host process" |
| `Code Helper (Plugin)` | "Xcode plugin for code assistance" | "VS Code plugin executor process" |
| `Code Helper (Renderer)` | "Renders code assistance and syntax highlighting" | "VS Code renderer process" |
| `context7-mcp` | "Core Audio processing" | "AI context provider MCP server" |
| `opencode` | "Opens source code editor" | "AI-powered CLI coding assistant" |
| `agent-browser-darwin-x64` | "Darwin browser user agent process" | "Browser automation agent process" |

**When to add an override**: If you notice the same process getting a wrong description every time, add it to `Config.HARDCODED_OVERRIDES`. The key is the process name as it appears in the `Name` column of the monitor.

## Level 3: Path Extraction

```python
def _extract_from_path(self, cmd, name):
    m = re.search(r"/([^/]+)\.app/", cmd)
    if m:
        return f"Active component of {m.group(1)}"
    if cmd.startswith(("/System/", "/usr/")):
        return None  # system process, defer to whatis/Groq
    return None
```

When a process is inside an `.app` bundle, we can extract the app name from its path:

| Command path | Extracted description |
|-------------|----------------------|
| `/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper.app/...` | "Active component of Visual Studio Code" |
| `/Applications/Brave Browser.app/Contents/Frameworks/Brave Browser Helper.app/...` | "Active component of Brave Browser" |
| `/System/Library/CoreServices/Finder.app/...` | "Active component of Finder" |

This produces **vague but never wrong** descriptions. It's a fallback, not the ideal result. The background thread will later replace it with a better AI description.

**Why not extract from Info.plist?** An earlier version used `plistlib` to parse `Info.plist` for `CFBundleDisplayName`. This was abandoned because:
1. It's slow (disk I/O for every process)
2. Many `.app` bundles are nested frameworks without their own Info.plist
3. The regex approach is instantaneous and good enough as a fallback

## Level 4: Whatis (Background)

```python
def _try_whatis(self, name):
    clean = re.sub(r"\(.*?\)", "", name).split()[0]
    try:
        out = subprocess.check_output(f"whatis {clean} 2>/dev/null", ...)
        for line in out.splitlines():
            if line.strip().startswith(clean + "(") or line.strip().startswith(clean + " "):
                parts = re.split(r"\s+[–-]\s+", line, maxsplit=1)
                return parts[1].strip()[:80]
    except:
        return None
```

`whatis` searches the system's mandb (manual page database) and returns one-line descriptions. It's the same command that powers `man -f`.

**Why it's in the background path**: On macOS, `whatis` is surprisingly slow:
- First call: ~2-5 seconds (sometimes triggers `makewhatis` rebuild)
- Subsequent calls: ~1-3 seconds per process
- Worst case (many results like `launchd`): 8+ seconds

If called synchronously for 100 daemons, the user would wait **minutes** before seeing anything.

**Parser details**: The raw `whatis launchd` output looks like:
```
WiFiVelocityAgent(8) - launchd agent for the WiFiVelocity framework
launchctl(1)         - Interfaces with launchd
launchd(8)           - System wide and per-user daemon/agent manager   ← this one
launchd.plist(5)     - System wide and per-user daemon/agent configuration files
```

The parser finds the line where the command name appears right before `(` and extracts the text after ` - `.

**Whatis is only tried for non-USER_APP processes**. If the classifier already determined the process is a user application, there's no point asking whatis (it won't have a man page).

## Level 5: Groq AI (Background)

```python
desc = groq.describe(p["name"])
```

If whatis returned nothing, the tool asks a free cloud AI (Groq). See [04-groq-ai-integration.md](./04-groq-ai-integration.md) for the full details.

Key parameters:
- Model: `llama-3.1-8b-instant` (fastest, 14,400 req/day free)
- System prompt: `"You are a macOS expert. Provide a short technical description (5-8 words) for the given macOS process name."`
- Temperature: 0.2 (low creativity, consistent output)
- Max tokens: 30

The AI is optimized for **brevity and consistency** rather than deep analysis. A typical response is:

```
WindowServer → "Manages macOS graphical user interface rendering"
configd     → "System configuration and network settings manager"
Python      → "High-level interpreted programming language"
```

## Level 6: Generic Fallback

```python
if not desc:
    desc = f"macOS process: {p['name']}"
```

If every engine fails (cache miss, no override, no .app path, whatis timed out, Groq errored), the process gets a factual but uninformative label. This is rare in practice (<3% of processes).

## The `resolve_immediate` vs `resolve_background` split

```python
# Called from main thread — must be instant
def resolve_immediate(self, name, cmd, category):
    cached = self.cache.get(name)
    if cached: return ...
    if name in HARDCODED_OVERRIDES: return ...
    path_desc = self._extract_from_path(cmd, name)
    if path_desc: return ...
    return None  # defer to background

# Called from background thread — can be slow
def resolve_background(self, name, cmd, description, category, source):
    self.cache.set(name, description, category, source)
```

The two-method design makes the blocking/fast path explicit. `resolve_immediate` never calls whatis or Groq — it's strictly cache → overrides → path extraction. `resolve_background` is a simple wrapper around `cache.set()`; the actual whatis/Groq logic lives in `mac_monitor_groq.py:background_resolver()`.

## Measuring hit rate

On a typical Mac with ~480 processes:

| Phase | Resolved | % |
|-------|----------|---|
| Immediate (cache + override + path) | 125 | 26% |
| Background (whatis + Groq) | 352 | 73% |
| Fallback | 6 | 1% |

On the **second run**, the cache converts most background resolutions to immediate:

| Phase | Resolved | % |
|-------|----------|---|
| Immediate (cache from previous run) | ~470 | 98% |
| New processes needing background | ~10 | 2% |
