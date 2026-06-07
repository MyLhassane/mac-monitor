#!/usr/bin/env python3
"""
macOS Process Monitor - Groq AI
Instant snapshot + background AI/Whatis descriptions + kill interface
"""

import sys
import time
import threading
import select
import os as _os
from modules import (
    ProcessCache, ProcessSnapshot, DescriptionResolver,
    GroqProvider, TerminalUI, ProcessClassifier,
)


def main():
    cache = ProcessCache()
    snapshot = ProcessSnapshot.capture()
    print(f"\u2611 {len(snapshot)} processes captured")

    for p in snapshot:
        p["category"] = ProcessClassifier.classify(p["name"], p["cmd"])

    resolver = DescriptionResolver(cache)
    pending = []

    for p in snapshot:
        desc, cat, source = resolver.resolve_immediate(
            p["name"], p["cmd"], p["category"]
        )
        if desc:
            p["desc"] = desc
            p["source"] = source
            p["resolved"] = True
        else:
            pending.append(p)

    groq = None
    if pending:
        try:
            groq = GroqProvider()
        except RuntimeError as e:
            print(f"\u26a0 {e}")
            print("Falling back to local descriptions only.")
            for p in pending:
                p["desc"] = f"macOS process: {p['name']}"
                p["resolved"] = True
                resolver.cache.set(p["name"], p["desc"], p["category"], "fallback")
            pending = []

    killable = {}
    resolver_active = len(pending) > 0
    TerminalUI.clear()
    TerminalUI.render(
        snapshot, killable,
        resolver_active=resolver_active,
        unresolved_count=len(pending),
    )

    def background_resolver():
        nonlocal resolver_active
        pending_local = list(pending)

        for p in pending_local:
            desc = None
            source = None

            if p["category"] != "USER_APP":
                desc = resolver._try_whatis(p["name"])
                source = "whatis" if desc else None

            if not desc:
                desc = groq.describe(p["name"]) if groq else None
                source = "groq" if desc else None

            if not desc:
                desc = f"macOS process: {p['name']}"
                source = "fallback"

            resolver.resolve_background(p["name"], p["cmd"], desc, p["category"], source)
            p["desc"] = desc
            p["source"] = source
            p["resolved"] = True

            if p in pending:
                pending.remove(p)
            remaining = len(pending)
            TerminalUI.render(
                snapshot, killable,
                resolver_active=remaining > 0,
                unresolved_count=remaining,
            )

        resolver_active = False
        TerminalUI.render(
            snapshot, killable,
            resolver_active=False,
        )

    if pending and groq:
        t = threading.Thread(target=background_resolver, daemon=True)
        t.start()

    while True:
        try:
            i, _, _ = select.select([sys.stdin], [], [], 0.3)
            if i:
                user_input = sys.stdin.readline().strip().lower()
                if user_input == "q":
                    print("\nExiting.")
                    break
                elif user_input == "r" and not resolver_active:
                    TerminalUI.clear()
                    TerminalUI.render(
                        snapshot, killable,
                        resolver_active=False,
                    )
                    continue
                elif user_input in killable:
                    pid, name = killable[user_input]
                    print(f"\n\u26a0 Terminate {name} (PID: {pid})? (y/n): ",
                          end="", flush=True)
                    confirm = sys.stdin.readline().strip().lower()
                    if confirm == "y":
                        try:
                            _os.kill(int(pid), 9)
                            print(f"\u2705 {name} terminated.")
                        except Exception as e:
                            print(f"\u274c Failed: {e}")
                    TerminalUI.clear()
                    TerminalUI.render(
                        snapshot, killable,
                        resolver_active=resolver_active,
                        unresolved_count=len(pending) if resolver_active else 0,
                    )
                elif user_input:
                    print("\nInvalid selection.")
                    sys.stdout.write("Action >> ")
                    sys.stdout.flush()
        except (KeyboardInterrupt, EOFError):
            print("\nExiting.")
            break


if __name__ == "__main__":
    main()
