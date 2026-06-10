import os, json, time, sys
from dotenv import load_dotenv
from groq import Groq
from rich.live import Live
from rich.table import Table
from rich.box import SIMPLE
from rich.console import Console

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from modules.snapshot import ProcessSnapshot
from modules.classifier import ProcessClassifier

load_dotenv()

api_key = os.getenv("GROQ_API_KEY") or os.environ.get("GROQ_API_KEY")
if not api_key:
    raise RuntimeError("GROQ_API_KEY not found")
client = Groq(api_key=api_key)
console = Console()

def make_table(title, data, style="bold #6ecbf5"):
    table = Table(title=title, box=SIMPLE, title_style=style)
    table.add_column("PID", style="dim", width=6)
    table.add_column("Name", width=28)
    table.add_column("CPU%", justify="right", width=6)
    table.add_column("MEM%", justify="right", width=6)
    table.add_column("Description", width=50)
    table.add_column("Source", width=10)
    for p in data:
        table.add_row(
            str(p["pid"]),
            p["name"][:28],
            f"{p['cpu']:.1f}",
            f"{p['mem']:.1f}",
            p.get("desc", "") or "",
            p.get("source", "") or "",
        )
    return table

def batch_describe(process_names, category):
    if not process_names:
        return {}
    prompt = (
        f"You are a macOS expert. Below is a JSON list of {category} process names.\n"
        "For each process, return a SHORT technical description (max 8 words).\n"
        "--- INPUT ---\n"
        f"{json.dumps(process_names)}\n"
        "--- OUTPUT ---\n"
        "Return a JSON object mapping each process name to its description.\n"
        'Example: {"Finder": "File manager GUI", "kernel_task": "CPU thermal throttling"}'
    )
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[
            {"role": "system",
             "content": "You are a macOS expert. Respond with valid JSON only, no extra text or markdown."},
            {"role": "user", "content": prompt},
        ],
        temperature=0.2,
        max_tokens=len(process_names) * 25,
        response_format={"type": "json_object"},
    )
    try:
        return json.loads(response.choices[0].message.content)
    except Exception:
        return {}

console.print("[bold] Capturing processes...[/bold]")
snapshot = ProcessSnapshot.capture()

for p in snapshot:
    p["category"] = ProcessClassifier.classify(p["name"], p["cmd"])

user_apps = [p for p in snapshot if p["category"] == "USER_APP"]
bg_services = [p for p in snapshot if p["category"] == "BACKGROUND_SERVICE"]
sys_cores = [p for p in snapshot if p["category"] == "SYSTEM_CORE"]

user_apps.sort(key=lambda x: x["cpu"] + x["mem"], reverse=True)
bg_services.sort(key=lambda x: x["cpu"] + x["mem"], reverse=True)

console.print(f"  USER_APPS: [green]{len(user_apps)}[/green] | "
      f"BACKGROUND: [blue]{len(bg_services)}[/blue] | "
      f"SYSTEM_CORE: [dim]{len(sys_cores)}[/dim]")
console.print(f"  Total: [bold]{len(snapshot)}[/bold]\n")

user_names = [p["name"] for p in user_apps]
bg_names = [p["name"] for p in bg_services]

with Live(console=console, refresh_per_second=4, vertical_overflow="visible") as live:
    # Initial: user apps table, blank descriptions
    live.update(make_table("User Applications (fetching...)", user_apps))

    if user_names:
        descriptions = batch_describe(user_names, "user")
        for p in user_apps:
            if p["name"] in descriptions:
                p["desc"] = descriptions[p["name"]]
                p["source"] = "Groq"
            else:
                p["desc"] = "[dim]unresolved[/dim]"
                p["source"] = "[dim]–[/dim]"

        live.update(make_table("User Applications", user_apps, "bold #22c55e"))
        time.sleep(1.5)

    if bg_names:
        live.update(make_table("Background Services (fetching...)", bg_services))
        bg_descriptions = batch_describe(bg_names, "background service")
        for p in bg_services:
            if p["name"] in bg_descriptions:
                p["desc"] = bg_descriptions[p["name"]]
                p["source"] = "Groq"
            else:
                p["desc"] = "[dim]unresolved[/dim]"
                p["source"] = "[dim]–[/dim]"

        live.update(make_table("Background Services", bg_services, "bold #6ecbf5"))
        time.sleep(1.5)

    # Final: all active (non-system) sorted by consumption
    all_active = user_apps + bg_services
    live.update(make_table("All Active Processes (sorted by CPU+MEM)", all_active))
    time.sleep(10)
