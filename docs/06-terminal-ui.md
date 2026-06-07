# Terminal UI

The UI module handles all terminal rendering and user interaction. It's designed for a **dark terminal** with ANSI color support (iTerm2, Terminal.app, WezTerm, etc.).

## Rendering — `TerminalUI.render()`

### Layout structure

```
════════════════════════════════════════════════════════════════════════════════════════════════════════
    ⚡ macOS PROCESS MONITOR - Groq AI (instant + background resolution) ⚡
════════════════════════════════════════════════════════════════════════════════════════════════════════

🟢 [SECTION 1] USER APPLICATIONS (Safe to Terminate)
   ID    PID     CPU%   MEM%   Process Name                     Description
   ────────────────────────────────────────────────────────────────────────────────────────────────────
   [1]   73600   61.4   0.5    Python                            High-level interpreted programming language.
   [2]   77094   13.6   1.4    opencode                          AI-powered CLI coding assistant.
   ...

🟡 [SECTION 2] BACKGROUND SERVICES (Kill if stuck)
   ID    PID     CPU%   MEM%   Process Name                     Description
   ────────────────────────────────────────────────────────────────────────────────────────────────────
   [51]  65868   9.4    5.2    Code Helper (Plugin)              ⏳ Resolving...
   ...

🔴 [SECTION 3] SYSTEM CORE (Locked / Do not kill)
   ID    PID     CPU%   MEM%   Process Name                     Description
   ────────────────────────────────────────────────────────────────────────────────────────────────────
   [-]   175     17.8   0.5    WindowServer                      Manages macOS graphical user interface rendering.
   ...

════════════════════════════════════════════════════════════════════════════════════════════════════════
 ⏳ Resolving descriptions in background (Groq AI) ... 358 remaining
    [Q] Exit  |  [Type ID Number] to Kill Process (kill immediately)
════════════════════════════════════════════════════════════════════════════════════════════════════════
Action >>
```

### ANSI control codes

The UI uses two ANSI escape sequences to avoid screen flicker:

```python
@staticmethod
def clear():
    sys.stdout.write("\033[2J\033[H")  # clear entire screen + move cursor home
    sys.stdout.flush()

@staticmethod
def cursor_home():
    sys.stdout.write("\033[H")          # move cursor home WITHOUT clearing
    sys.stdout.flush()
```

- `\033[2J` — Erase entire display
- `\033[H` — Move cursor to row 0, column 0 (home position)

The `render()` function calls `cursor_home()` at the start, then overwrites the previous content line by line. Since the new output has the same height as the old output, the effect is a seamless in-place update with **zero flicker**.

This replaces the common but problematic approach:
```python
os.system('clear')  # BAD: spawns a child process, causes visible flash
```

### Categorization and sorting

```python
user = sorted(
    [p for p in snapshot if p.get("category") == "USER_APP"],
    key=lambda x: x["cpu"], reverse=True
)
```

Each category is filtered and sorted by CPU usage descending. The top 50 processes per category are displayed (configurable via `SNAPSHOT_MAX_PER_CATEGORY`).

This means the most resource-hungry processes appear first, which is exactly what the user cares about.

### Killable IDs

```python
killable = {}
idx = 1
for p in user:
    id_str = f"[{idx}]"
    killable[str(idx)] = (p["pid"], p["name"])
    idx += 1
```

Only `USER_APP` and `BACKGROUND_SERVICE` entries get killable IDs. `SYSTEM_CORE` entries show `[-]` instead. The `killable` dict maps string IDs to `(PID, name)` tuples for the input handler.

### Status bar

```python
if resolver_active:
    print(" ⏳ Resolving descriptions in background (Groq AI) ... 358 remaining")
    print("    [Q] Exit  |  [Type ID Number] to Kill Process (kill immediately)")
else:
    print(" ✅ All descriptions resolved.")
    print("    [Q] Exit  |  [R] Refresh  |  [Type ID Number] to Kill Process")
```

The status bar changes depending on whether the background resolver is still working. Note that `[R] Refresh` only appears when resolution is complete — refreshing mid-resolution would restart the process and waste API calls.

### Input layout

```python
sys.stdout.write("Action >> ")
sys.stdout.flush()
```

The prompt sits on its own line, ready for keyboard input. `flush()` is necessary because `stdout` is line-buffered and the prompt doesn't end with a newline.

## Input handling — `main()` loop

### Non-blocking read with `select.select()`

```python
i, _, _ = select.select([sys.stdin], [], [], 0.3)
if i:
    user_input = sys.stdin.readline().strip().lower()
```

Python's `input()` blocks indefinitely, which would freeze the UI. Instead, `select.select()` checks if stdin has data available within 0.3 seconds. If no input arrives:
- The loop goes back to `select.select()` for another 0.3s wait
- The background thread can still update descriptions via its own `render()` calls
- The terminal effectively "idles" while descriptions fill in

If input arrives:
- `sys.stdin.readline()` reads it without blocking
- The input is processed: `q` → quit, `r` → refresh, number → kill

### Kill flow

```python
if user_input in killable:
    pid, name = killable[user_input]
    print(f"\n⚠ Terminate {name} (PID: {pid})? (y/n): ", end="", flush=True)
    confirm = sys.stdin.readline().strip().lower()
    if confirm == "y":
        try:
            os.kill(int(pid), 9)
            print(f"✅ {name} terminated.")
        except Exception as e:
            print(f"❌ Failed: {e}")
```

The kill flow:
1. Look up the entered ID in the `killable` dict
2. Ask for confirmation (double-tap safety)
3. Send `SIGKILL` (signal 9) — immediate termination
4. Re-render the table (the killed process stays listed since it's a static snapshot)

**Why SIGKILL and not SIGTERM?**  
SIGTERM (signal 15) asks a process to terminate gracefully. For a process monitor, when the user wants to kill something, they usually want it gone immediately. SIGKILL cannot be ignored or handled — the process terminates instantly.

**Permission handling**: If the process belongs to another user or is protected by SIP (System Integrity Protection), `os.kill()` raises `PermissionError`, which is caught and displayed.

### Refresh flow

```python
if user_input == "r" and not resolver_active:
    TerminalUI.clear()
    TerminalUI.render(snapshot, killable, resolver_active=False)
```

Refresh re-renders the current snapshot. It does **not** re-run `ps`. To get a fresh process list, the user must quit and restart.
