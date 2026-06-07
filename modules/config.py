import os
from pathlib import Path


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

    HARDCODED_OVERRIDES = {
        "Code Helper": "VS Code extension host process",
        "Code Helper (Plugin)": "VS Code plugin executor process",
        "Code Helper (Renderer)": "VS Code renderer process",
        "opencode": "AI-powered CLI coding assistant",
        "context7-mcp": "AI context provider MCP server",
        "agent-browser-darwin-x64": "Browser automation agent process",
        "progressd": "Background task progress tracker",
        "cloudd": "iCloud sync daemon process",
        "coreduetd": "Core Duet activity tracking daemon",
        "diskarbitrationd": "Disk arbitration and mounting daemon",
    }

    KNOWN_CLASSES = {
        "kernel_task": "SYSTEM_CORE",
        "launchd": "SYSTEM_CORE",
        "WindowServer": "SYSTEM_CORE",
        "UserEventAgent": "SYSTEM_CORE",
        "systemstats": "SYSTEM_CORE",
        "mds": "SYSTEM_CORE",
        "loginwindow": "SYSTEM_CORE",
        "syspolicyd": "SYSTEM_CORE",
        "notifyd": "SYSTEM_CORE",
        "configd": "BACKGROUND_SERVICE",
        "powerd": "BACKGROUND_SERVICE",
        "logd": "BACKGROUND_SERVICE",
        "taskgated": "BACKGROUND_SERVICE",
        "distnoted": "BACKGROUND_SERVICE",
        "cfprefsd": "BACKGROUND_SERVICE",
        "tccd": "BACKGROUND_SERVICE",
        "amfid": "BACKGROUND_SERVICE",
    }

    @classmethod
    def ensure_db_dir(cls):
        cls.DB_DIR.mkdir(parents=True, exist_ok=True)
