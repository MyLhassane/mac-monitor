import sys
import os


class TerminalUI:
    @staticmethod
    def clear():
        sys.stdout.write("\033[2J\033[H")
        sys.stdout.flush()

    @staticmethod
    def cursor_home():
        sys.stdout.write("\033[H")
        sys.stdout.flush()

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
