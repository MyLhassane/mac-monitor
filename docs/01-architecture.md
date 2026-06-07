# Architecture Overview

Mac Monitor uses a **two-phase resolution architecture**: show everything instantly, then enrich in the background. This guarantees the user never waits for the terminal to render.

## Core Principle

```
Phase 1 (Immediate):  Snapshot → Classify → Resolve (cache/hardcoded/path) → Render
Phase 2 (Background): For each unresolved process → Whatis → Groq AI → Cache → Re-render
```

The user sees a table of processes within **milliseconds** of launching. Descriptions marked as "⏳ Resolving..." fill in live as the background worker completes each one.

## Module Dependency Graph

```
mac_monitor_groq.py  (entry point, orchestrator)
     │
     ├── Config              (settings, overrides, known classes)
     ├── ProcessSnapshot     (ps -A wrapper)
     ├── ProcessClassifier   (USER_APP / BACKGROUND / SYSTEM_CORE)
     ├── ProcessCache        (SQLite persistence)
     ├── DescriptionResolver (fallback chain orchestrator)
     ├── GroqProvider        (AI client with rate limiter)
     └── TerminalUI          (ANSI rendering, input handling)
```

Dependencies flow **one way** — no circular imports. Each module imports only what it needs from siblings via `__init__.py`.

## Data Flow

### Startup Sequence

```
1. ProcessSnapshot.capture()
   → runs `ps -A -o pid,%cpu,%mem,comm`
   → returns list[dict] with pid, cpu, mem, cmd, name

2. ProcessClassifier.classify(name, cmd)
   → rules-based check (KNOWN_CLASSES, .app/, com.apple., suffix d, ...)
   → returns "USER_APP" | "BACKGROUND_SERVICE" | "SYSTEM_CORE"

3. DescriptionResolver.resolve_immediate(name, cmd, category)
   → SQLite cache? return
   → Hardcoded override? return
   → Path extraction? return
   → return None (defer to background)

4. TerminalUI.render(...)
   → sort by CPU descending within each category
   → print ANSI table with color-coded sections
   → mark unresolved entries as "⏳ Resolving..."

5. if pending:
     GroqProvider()  → load .env, validate API key
     threading.Thread(target=background_resolver).start()

6. while True:
     select.select([sys.stdin], timeout=0.3s)
     → handle 'q', 'r', kill-by-number
```

### Background Resolution Loop

```
for each pending process p:
   1. if p is not USER_APP:
        desc ← whatis(p.name)             # local, slow (~2-10s)
   2. if still no desc:
        desc ← GroqProvider.describe(p.name)  # cloud, fast (~0.5s)
   3. if still no desc:
        desc ← f"macOS process: {p.name}"     # generic fallback

   cache.set(p.name, desc, p.category, source)
   p.desc = desc
   p.resolved = True
   TerminalUI.render(...)  # re-render with updated description
```

## Thread Model

| Thread | Role | Lifetime |
|--------|------|----------|
| **Main thread** | Captures snapshot, renders UI, handles user input (q, kill, refresh) | Entire session |
| **Background resolver** (daemon) | Loops over pending list, calls whatis/Groq, updates snapshot, re-renders | Until all descriptions resolved |

The background thread is a **daemon thread** — it dies automatically when the main thread exits. There's no complex thread pool or async machinery; just a simple linear loop over a borrowed copy of the pending list.

## Key Design Decisions

### 1. Why not async?
Python's `asyncio` adds complexity (event loop management, async database drivers). A single daemon thread with blocking I/O is simpler and achieves the same UX: the UI stays responsive via `select.select()` with 0.3s timeout.

### 2. Why static snapshot instead of live updates?
Originally the tool re-ran `ps` every cycle, which caused two problems:
- **Flicker**: `os.system('clear')` created visible flashes
- **Jumping rows**: processes re-sorted by CPU each cycle, making it impossible to track a specific PID

The static snapshot approach (capture once, render forever, only update descriptions) solved both.

### 3. Why background resolution with no completion guarantee?
The daemon thread is fire-and-forget. If the user kills a process or quits before descriptions arrive, nothing breaks. The cache preserves results for the next session.

## File Layout

```
mac-monitor-groq/
├── mac_monitor_groq.py       Entry point (148 lines)
├── requirements.txt          2 dependencies: groq, python-dotenv
├── .env.example              Template for GROQ_API_KEY
├── modules/
│   ├── __init__.py           Re-exports all module classes
│   ├── config.py             Configuration constants + overrides
│   ├── database.py           SQLite cache (57 lines)
│   ├── snapshot.py           ps capture (28 lines)
│   ├── classifier.py         Process categorization (26 lines)
│   ├── descriptions.py       Resolution chain + whatis + path extraction (60 lines)
│   ├── groq_provider.py      AI client with rate limiting (54 lines)
│   └── ui.py                 Terminal rendering (82 lines)
└── docs/
    ├── README.md             User-facing docs
    ├── index.html            GitHub Pages site (bilingual)
    ├── 01-architecture.md    ← you are here
    ├── 02-snapshot-classification.md
    ├── 03-description-resolution-chain.md
    ├── 04-groq-ai-integration.md
    ├── 05-sqlite-caching-system.md
    ├── 06-terminal-ui.md
    └── 07-configuration-guide.md
```
