# mac-monitor-groq

macOS process monitor with AI-powered descriptions using Groq API (free).

## Features

- Instant process snapshot via `ps -A`
- Three-section layout: USER_APPS / BACKGROUND / SYSTEM_CORE
- AI-powered descriptions via Groq (free tier: 14,400 req/day)
- Multi-level fallback chain for reliability
- Kill processes directly from the TUI
- SQLite cache for instant repeat lookups
- Zero flicker (ANSI control codes, no `os.system('clear')`)
- Static snapshot (IDs don't change during refresh)

## Description Resolution Chain

When looking up a process description, the tool tries each source in order:

1. **SQLite cache** (instant) - previously resolved descriptions
2. **Hardcoded overrides** (instant) - fixes known AI hallucinations (e.g., Code Helper → Xcode)
3. **whatis** (local, macOS daemons) - system's built-in manual page database
4. **Path extraction** (local, .app bundles) - extracts app name from bundle path
5. **Groq AI** (cloud, rate-limited) - llama-3.1-8b-instant, free tier 14,400 req/day
6. **Generic fallback** - "macOS process: {name}"

## Quick Start

1. **Get a free Groq API key** at https://console.groq.com (no credit card required)

2. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Set your API key**:
   ```bash
   cp .env.example .env
   # Edit .env and paste your Groq API key
   ```

   Or export it:
   ```bash
   export GROQ_API_KEY="gsk_your_key_here"
   ```

4. **Run**:
   ```bash
   python mac_monitor_groq.py
   ```

## Usage

| Action | Input |
|--------|-------|
| Kill a process | Type the ID number and press Enter |
| Exit | `q` |
| Refresh display | `r` (after all descriptions resolve) |

## Project Structure

```
mac-monitor-groq/
├── mac_monitor_groq.py    # Entry point
├── modules/
│   ├── __init__.py
│   ├── config.py          # Settings, overrides, known classes
│   ├── database.py        # SQLite cache
│   ├── snapshot.py        # ps capture
│   ├── classifier.py      # Process categorization
│   ├── descriptions.py    # Resolution chain
│   ├── groq_provider.py   # Groq API client
│   └── ui.py              # Terminal UI (ANSI)
├── requirements.txt
├── .env.example
└── README.md
```

## Cache

Database is stored at `~/.mac-monitor-groq/process_cache.db`. It preserves descriptions between runs so previously resolved processes appear instantly on subsequent launches.

## Requirements

- Python 3.8+
- macOS
- Groq API key (free, no credit card)
