import os
import time
import threading
from groq import Groq
from dotenv import load_dotenv
from .config import Config

load_dotenv()


class GroqProvider:
    def __init__(self):
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            api_key = os.environ.get("GROQ_API_KEY")
        if not api_key:
            raise RuntimeError(
                "GROQ_API_KEY not found. Set it in .env or export GROQ_API_KEY=..."
            )
        self.client = Groq(api_key=api_key)
        self._lock = threading.Lock()
        self._last_call = 0.0
        self.daily_count = 0
        self.max_daily = 14000

    def describe(self, name):
        with self._lock:
            elapsed = time.time() - self._last_call
            if elapsed < Config.GROQ_DELAY_BETWEEN:
                time.sleep(Config.GROQ_DELAY_BETWEEN - elapsed)

            if self.daily_count >= self.max_daily:
                return None

            self._last_call = time.time()
            self.daily_count += 1

        try:
            response = self.client.chat.completions.create(
                model=Config.GROQ_MODEL,
                messages=[
                    {
                        "role": "system",
                        "content": "You are a macOS expert. Provide a short technical description (5-8 words) for the given macOS process name. No markdown, no quotes, no punctuation at end.",
                    },
                    {"role": "user", "content": name},
                ],
                temperature=0.2,
                max_tokens=30,
            )
            desc = response.choices[0].message.content.strip().rstrip(".")
            return desc
        except Exception:
            return None
