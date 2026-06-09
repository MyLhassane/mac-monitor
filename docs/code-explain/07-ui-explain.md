# TerminalUI (ANSI rendering, input handling)

modules/ui.py

### /explain `TerminalUI`

Here is a summary of what the `TerminalUI` class does:

- `clear()`: Clears the terminal screen.
- `cursor_home()`: Moves the cursor to the home position of the terminal.
- `render(snapshot, killable, resolver_active, unresolved_count=None)`: Renders a table of process information in the terminal. It takes in a `snapshot` of process information, a `killable` dictionary to store process information for killing, a `resolver_active` flag to indicate if the process descriptions are being resolved in the background, and an optional `unresolved_count` to display the number of remaining unresolved descriptions. The function first sorts the process information into three sections: user applications, background services, and system core. It then prints the table in the terminal, displaying the process ID, CPU usage, memory usage, process name, and description. Finally, it prints some additional information at the bottom of the table, such as the number of remaining unresolved descriptions or instructions for killing a process.

### /explain `clear`

```python title:'clear method'
        @staticmethod
    def clear():
        sys.stdout.write("\033[2J\033[H")
        sys.stdout.flush()
```

This code snippet defines a static method called `clear` in a class. When this method is called, it clears the terminal screen by writing a special escape sequence to the standard output (`sys.stdout`). The escape sequence `\033[2J` clears the entire screen, and `\033[H` moves the cursor to the top-left corner of the screen. The `flush()` method is called to ensure that the output is immediately displayed on the screen.

### /explain `cursor_home`

```python title:'cursor_home method'
    @staticmethod
    def cursor_home():
        sys.stdout.write("\033[H")
        sys.stdout.flush()
```

This code snippet defines a static method called `cursor_home()` in a class. It uses the ANSI escape sequence `\033[H` to move the cursor to the beginning of the current line in the terminal. The `sys.stdout.write()` function is used to write the escape sequence to the standard output, and `sys.stdout.flush()` is called to ensure that the output is immediately displayed on the terminal.

### /explain `render`

```python title:'render method'
    @staticmethod
    def render(snapshot, killable, resolver_active, unresolved_count=None):
        killable.clear()

        user = sorted(
            [p for p in snapshot if p.get("category") == "USER_APP"],
            key=lambda x: x["cpu"], reverse=True
        )
        bg = sorted(
            [p for p in snapshot if p.get("category") == "BACKGROUND_SERVICE"],
            key=lambda x: x["cpu"], reverse=True
        )
        core = sorted(
            [p for p in snapshot if p.get("category") == "SYSTEM_CORE"],
            key=lambda x: x["cpu"], reverse=True
        )

        TerminalUI.cursor_home()
        print("=" * 120)
        print("    \u26a1 macOS PROCESS MONITOR - Groq AI (instant + background resolution) \u26a1")
        print("=" * 120)

        idx = 1
        sections = [
            ("\n\U0001f7e2 [SECTION 1] USER APPLICATIONS (Safe to Terminate)", user, True),
            ("\n\U0001f7e1 [SECTION 2] BACKGROUND SERVICES (Kill if stuck)", bg, True),
            ("\n\U0001f534 [SECTION 3] SYSTEM CORE (Locked / Do not kill)", core, False),
        ]

        for title, items, killable_section in sections:
            print(title)
            print(
                f"   {'ID':<5} {'PID':<7} {'CPU%':<6} {'MEM%':<6}"
                f" {'Process Name':<35} {'Description'}"
            )
            print("   " + "-" * 112)
            for p in items[:50]:
                name_trunc = p["name"][:35]
                desc = p.get("desc") or "\u23f3 Resolving..."
                desc_trunc = desc[:55]

                if killable_section:
                    id_str = f"[{idx}]"
                    killable[str(idx)] = (p["pid"], p["name"])
                    idx += 1
                else:
                    id_str = "[-]"

                print(
                    f"   {id_str:<5} {p['pid']:<7} {p['cpu']:<6.1f}"
                    f" {p['mem']:<6.1f} {name_trunc:<35} {desc_trunc}"
                )

        print("\n" + "=" * 120)
        if resolver_active:
            remaining = unresolved_count if unresolved_count is not None else "?"
            print(
                f" \u23f3 Resolving descriptions in background (Groq AI)"
                f" ... {remaining} remaining"
            )
            print("    [Q] Exit  |  [Type ID Number] to Kill Process (kill immediately)")
        else:
            print(" \u2705 All descriptions resolved.")
            print("    [Q] Exit  |  [R] Refresh  |  [Type ID Number] to Kill Process")
        print("=" * 120)
        sys.stdout.write("Action >> ")
        sys.stdout.flush()
```

This code snippet defines a static method called `render` in the `TerminalUI` class. The method takes in four parameters: `snapshot`, `killable`, `resolver_active`, and `unresolved_count`. 

The method first clears the terminal screen using the `clear` method of the `TerminalUI` class. 

Then, it sorts the `snapshot` list into three different categories: `user`, `bg`, and `core`, based on the value of the `category` key in each dictionary. 

After that, it prints a heading and a separator line on the terminal screen. 

Next, it iterates over the `sections` list, which contains tuples of title, items, and a flag indicating whether the section is killable or not. For each section, it prints the title, a table header, and a separator line. 

Inside the loop, it iterates over the items in the current section and prints each item in a formatted string. If the section is killable, it adds the item's `pid` and `name` to the `killable` dictionary and increments the `idx` counter. 

After printing all the items, it prints another separator line. If `resolver_active` is `True`, it prints a message indicating that descriptions are being resolved in the background and the number of remaining descriptions. Otherwise, it prints a message indicating that all descriptions have been resolved. 

Finally, it prints another separator line and prompts the user to enter an action.
