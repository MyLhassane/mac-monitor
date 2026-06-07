# Snapshot & Classification

Two modules handle the initial data pipeline: `ProcessSnapshot` captures raw process data from the OS, and `ProcessClassifier` assigns each process to one of three safety categories.

## ProcessSnapshot — `modules/snapshot.py`

### What it does

Runs the macOS `ps` command and parses its output into a list of dicts.

```python
# The actual command:
ps -A -o pid,%cpu,%mem,comm
```

| Flag | Meaning |
|------|---------|
| `-A` | All processes (not just terminal-attached) |
| `-o pid,%cpu,%mem,comm` | Custom output format: PID, CPU%, MEM%, command path |

### Parsing logic

```python
out = subprocess.check_output("ps -A -o pid,%cpu,%mem,comm", shell=True, text=True)
lines = out.strip().split("\n")[1:]  # skip header
```

Each line is split on **whitespace with maxsplit=3** because `comm` (the command path) may contain spaces:

```python
parts = line.split(None, 3)
# parts[0] = PID (int)
# parts[1] = CPU% (float)
# parts[2] = MEM% (float)
# parts[3] = command path (string)
```

### Return value

```python
[
    {
        "pid": 1234,          # int — process ID
        "cpu": 12.5,          # float — CPU usage %
        "mem": 3.2,           # float — memory usage %
        "cmd": "/usr/bin/python3",  # string — full command path
        "name": "python3",    # string — basename of cmd
        "desc": None,         # str or None — to be filled later
        "category": None,     # str — to be filled by classifier
        "source": None,       # str — origin of description
        "resolved": False,    # bool — whether description exists
    },
    ...
]
```

### Why `comm` and not `args`?

`ps -o comm` gives the executable path (e.g., `/Applications/Firefox.app/Contents/MacOS/firefox`). `ps -o args` gives the full command line including arguments, which varies wildly and isn't useful for classification. The basename of `comm` is the process name (e.g., `firefox`).

### Edge case: truncated paths

macOS `ps` truncates paths longer than ~256 characters. For those cases, the tool falls back to the truncated value. The basename is usually still correct.

---

## ProcessClassifier — `modules/classifier.py`

### What it does

Assigns every process to one of three categories based on its name and command path. The category determines:

| Category | Color | Killable? | Meaning |
|----------|-------|-----------|---------|
| `USER_APP` | 🟢 Green | Yes | Applications the user launched |
| `BACKGROUND_SERVICE` | 🟡 Yellow | Yes (with caution) | System daemons, helpers, agents |
| `SYSTEM_CORE` | 🔴 Red | **No** | Kernel processes, protected system services |

### Classification rules (in priority order)

```python
@classmethod
def classify(cls, name, cmd):
```

| Priority | Rule | Example | Category |
|----------|------|---------|----------|
| 1 | If name is in `Config.KNOWN_CLASSES` | `kernel_task`, `launchd`, `WindowServer` | As defined |
| 2 | If `cmd` contains `.app/` | `Finder.app/.../Finder` | `USER_APP` |
| 3 | If name starts with `com.apple.` | `com.apple.geod` | `BACKGROUND_SERVICE` |
| 4 | If name ends with `d` (daemon) and doesn't contain `Helper` | `syslogd`, `configd`, `notifyd` | `BACKGROUND_SERVICE` |
| 5 | If name is a known user-facing app | `Finder`, `Dock`, `Terminal`, `Activity Monitor` | `USER_APP` |
| 6 | If `cmd` is inside `/usr/libexec/` | `/usr/libexec/secinitd` | `BACKGROUND_SERVICE` |
| 7 | Everything else | `Python`, `node`, `Code` | `USER_APP` |

### Rule rationales

**Rule 1 — KNOWN_CLASSES**: A manually curated list in `config.py` for processes whose category is unambiguous. `kernel_task` must never be killable; `amfid` (Apple Mobile File Integrity) is a background security service.

**Rule 2 — `.app/` in path**: Any binary inside an `.app` bundle is a user-facing application component. This catches both main executables (`Finder`, `Firefox`) and helpers (`Code Helper (Renderer)`, `Brave Browser Helper`).

**Rule 3 — `com.apple.` prefix**: Apple's background agents all use this naming convention (`com.apple.geod`, `com.apple.dock.extra`).

**Rule 4 — Trailing `d`**: Traditional Unix daemon naming convention. `syslogd`, `configd`, `notifyd`. The `Helper` exclusion prevents `Code Helper` from being classified as a daemon (it would if the rule were just `name.endswith("d")`).

**Rule 5 — Known user apps**: A small whitelist for processes that end with `d` (like `Finder`... wait, `Finder` doesn't end with `d`). This primarily catches processes whose path doesn't contain `.app/` but are clearly user applications.

**Rule 6 — `/usr/libexec/`**: macOS internal helper executables. Always background services.

**Rule 7 — Default**: Anything that doesn't match any rule is assumed to be a user application. This is a conservative default — better to show it as killable (green) than to lock it from termination.

### Why not use a machine learning classifier?

Good question. A rule-based classifier was chosen because:
1. **Zero dependencies** — no ML framework, no model download
2. **Deterministic** — same process always gets the same category
3. **Auditable** — anyone can read the 14-line function and understand exactly why a process was classified a certain way
4. **Performance** — takes microseconds, not milliseconds

### Example classifications

| Process | `cmd` | Category | Rule |
|---------|-------|----------|------|
| `kernel_task` | `(kernel)` | `SYSTEM_CORE` | 1 (KNOWN_CLASSES) |
| `launchd` | `/sbin/launchd` | `SYSTEM_CORE` | 1 (KNOWN_CLASSES) |
| `Finder` | `/System/.../Finder.app/...` | `USER_APP` | 2 (`.app/`) |
| `Code Helper (Renderer)` | `/Applications/VS Code.app/...` | `USER_APP` | 2 (`.app/`) |
| `configd` | `/usr/libexec/configd` | `BACKGROUND_SERVICE` | 4 (ends with `d`) |
| `com.apple.geod` | `/usr/libexec/geod` | `BACKGROUND_SERVICE` | 3 (`com.apple.`) |
| `Python` | `/usr/bin/python3` | `USER_APP` | 7 (default) |
| `syslogd` | `/usr/sbin/syslogd` | `BACKGROUND_SERVICE` | 4 (ends with `d`) |
