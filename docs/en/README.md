# Mac Monitor Documentation

> A macOS process monitor CLI tool with AI-powered descriptions, smart classification, and a 6-level fallback resolution chain.

## Quick links

- [Architecture Overview](01-architecture.md)
- [Snapshot & Classification](02-snapshot-classification.md)
- [Description Resolution Chain](03-description-resolution-chain.md)
- [Groq AI Integration](04-groq-ai-integration.md)
- [SQLite Caching System](05-sqlite-caching-system.md)
- [Terminal UI](06-terminal-ui.md)
- [Configuration Guide](07-configuration-guide.md)

## Overview

**Mac Monitor** captures every running process on macOS, classifies it into one of three categories (USER_APP, BACKGROUND_SERVICE, SYSTEM_CORE), and provides a clear English description using a smart fallback chain:

1. SQLite Cache (instant)
2. Hardcoded Overrides (instant)
3. Path Extraction (instant)
4. Whatis (fast)
5. Groq AI (online, 14,400 free descriptions/day)
6. Generic Fallback (last resort)

The tool is designed to be **lightweight**, **offline-capable**, and **free** — no credit card required.
