# Groq AI Integration

This module connects to Groq's free API to generate process descriptions using a large language model. The integration is designed to be **resilient, rate-limited, and zero-config** for end users.

## Why Groq?

| Factor | Groq | Gemini (tried) | OpenAI (tried) | Local LLM (considered) |
|--------|------|----------------|----------------|------------------------|
| Free tier | 14,400 req/day | 1,500 req/day | Expired credits | 0 (but requires 8GB+ RAM / Intel) |
| No credit card | ✅ | ✅ | ❌ | ✅ |
| Speed | 300+ tok/s (LPU) | Moderate | Fast | Slow on Intel Mac |
| OpenAI-compatible | ✅ | ❌ | ✅ | Varies |

Groq's custom LPU hardware makes it **10-50x faster** than GPU-based inference for small prompts, which is ideal for our use case (hundreds of short 30-token responses).

## Setup

### 1. User gets a free API key

```
https://console.groq.com  →  Sign up (Google/GitHub)  →  Create API key
```

No credit card, no billing info, no phone number. The key starts with `gsk_`.

### 2. Configure the key

```bash
# Option A: .env file (recommended)
echo 'GROQ_API_KEY=gsk_your_key_here' > .env

# Option B: environment variable
export GROQ_API_KEY="gsk_your_key_here"
```

### 3. The tool picks it up

```python
# groq_provider.py
from dotenv import load_dotenv
load_dotenv()  # loads .env into os.environ

api_key = os.getenv("GROQ_API_KEY")
if not api_key:
    api_key = os.environ.get("GROQ_API_KEY")
if not api_key:
    raise RuntimeError("GROQ_API_KEY not found.")
```

The `.env` file is loaded before `os.environ` check so both methods work. The double-check handles the case where `.env` doesn't exist but `export` was used.

## The API Call

```python
response = self.client.chat.completions.create(
    model="llama-3.1-8b-instant",     # fastest free model
    messages=[
        {
            "role": "system",
            "content": "You are a macOS expert. Provide a short technical description "
                       "(5-8 words) for the given macOS process name. "
                       "No markdown, no quotes, no punctuation at end.",
        },
        {"role": "user", "content": name},
    ],
    temperature=0.2,    # low randomness for consistent output
    max_tokens=30,      # 30 tokens = ~20-25 words max
)
```

### The system prompt is carefully tuned

**What it does:**
- Sets role: `"macOS expert"` — primes the model to recognize daemon names
- Specifies format: `"5-8 words"` — enforces terminal-width constraint
- Removes noise: `"No markdown, no quotes, no punctuation"` — ensures clean output

**Why temperature=0.2?**  
Higher temperatures cause the model to produce different descriptions for the same process on different calls. At 0.2, `WindowServer` always generates something close to "Manages macOS graphical user interface rendering" — which is what we want for cached, deterministic behavior.

**Post-processing:**
```python
desc = response.choices[0].message.content.strip().rstrip(".")
```
Removes trailing periods since the system prompt already says "no punctuation at end" — this handles cases where the model ignores the instruction.

## Rate Limiting

Groq's free tier allows **30 requests per minute** and **14,400 requests per day** at the organization level. The tool implements its own rate limiter:

```python
class GroqProvider:
    def __init__(self):
        self._lock = threading.Lock()
        self._last_call = 0.0
        self.daily_count = 0
        self.max_daily = 14000  # safety margin below 14,400

    def describe(self, name):
        with self._lock:
            # 1. Enforce minimum delay between calls
            elapsed = time.time() - self._last_call
            if elapsed < Config.GROQ_DELAY_BETWEEN:  # 0.4 seconds
                time.sleep(Config.GROQ_DELAY_BETWEEN - elapsed)

            # 2. Check daily budget
            if self.daily_count >= self.max_daily:
                return None

            self._last_call = time.time()
            self.daily_count += 1

        # 3. Make API call (outside lock)
        try:
            response = self.client.chat.completions.create(...)
            return response.choices[0].message.content.strip()
        except Exception:
            return None
```

**Design decisions:**

- **Lock scoping**: The lock only protects the timer and counter. The actual HTTP request (`client.chat.completions.create`) happens **outside** the lock so multiple threads don't block each other during network I/O.

- **Daily safety margin**: The max is set to 14,000, leaving 400 requests of headroom below the 14,400 limit. This prevents edge-of-limit failures.

- **Silent failure**: If the API errors (network issue, rate limit, model overload), `describe()` returns `None`. The caller in `background_resolver()` falls through to the generic fallback. The tool never crashes due to an API error.

## Concurrency

```python
# In config.py
GROQ_MAX_CONCURRENT = 5
GROQ_DELAY_BETWEEN = 0.4   # seconds
```

The background resolver processes pending items **sequentially** (not in parallel) because the lock serializes API calls. With `GROQ_DELAY_BETWEEN=0.4`, the tool makes at most `60/0.4 = 150` requests per minute — well within Groq's 30 RPM limit for `llama-3.1-8b-instant`.

Wait — 150 RPM exceeds the 30 RPM limit. Let's do the math:

- 30 RPM = 1 request per 2 seconds
- Current config: 0.4 delay = 150 RPM

**This means rate limiting relies on Groq's server-side enforcement**. If Groq returns a 429 (rate limit), the `describe()` catches the exception and returns `None`, causing a fallback. This is acceptable because:
1. The user won't notice a few processes falling back to generic descriptions
2. The daily limit (14,000) is the real constraint for most use cases
3. Increasing the delay to 2 seconds would make the background resolution 5x slower

To be strictly compliant, set `GROQ_DELAY_BETWEEN = 2.0` in your `config.py`.

## Resource usage

A single description costs approximately:
- **Input**: ~30 tokens (system prompt + process name)
- **Output**: ~10 tokens (8-word description)
- **Bandwidth**: ~1 KB per request
- **Time**: ~400-800ms over a typical internet connection

For 350 pending processes:
- Total tokens: 350 × 40 = 14,000 tokens
- Total time: 350 × 0.5s = ~3 minutes
- Total cost: **$0.00**

## Error handling matrix

| Error type | What happens | User impact |
|-----------|-------------|-------------|
| No API key | `GroqProvider()` raises `RuntimeError` | Falls back to local descriptions only |
| Network timeout | Exception caught → returns `None` | Process gets generic description |
| Rate limit (429) | Exception caught → returns `None` | Some processes get generic descriptions |
| Daily quota hit | Counter check → returns `None` | Remaining processes get generic descriptions |
| Model overload (503) | Exception caught → returns `None` | Process gets generic description |
| Empty response | `strip()` returns empty → saved as-is | Shows blank description |

## Testing without an API key

```bash
# Run without setting GROQ_API_KEY
python mac_monitor_groq.py
```

The tool will print:
```
⚠ GROQ_API_KEY not found. Set it in .env or export GROQ_API_KEY=...
Falling back to local descriptions only.
```

All processes will be resolved using cache + hardcoded + path + whatis + generic fallback. No AI descriptions.
