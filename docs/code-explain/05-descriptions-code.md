modules/descriptions.py

```python title:DescriptionResolver
import re
import subprocess
from .config import Config
from .database import ProcessCache
from .classifier import ProcessClassifier


class DescriptionResolver:
    def __init__(self, cache=None):
        self.cache = cache or ProcessCache()

    def resolve_immediate(self, name, cmd, category):
        cached = self.cache.get(name)
        if cached:
            return cached["description"], category, cached["source"]

        if name in Config.HARDCODED_OVERRIDES:
            desc = Config.HARDCODED_OVERRIDES[name]
            self.cache.set(name, desc, category, "hardcoded")
            return desc, category, "hardcoded"

        path_desc = self._extract_from_path(cmd, name)
        if path_desc:
            self.cache.set(name, path_desc, category, "path")
            return path_desc, category, "path"

        return None, category, None

    def resolve_background(self, name, cmd, description, category, source):
        self.cache.set(name, description, category, source)

    def _try_whatis(self, name):
        clean = re.sub(r"\(.*?\)", "", name).split()[0]
        if not clean or len(clean) < 2:
            return None
        try:
            out = subprocess.check_output(
                f"whatis {clean} 2>/dev/null", shell=True, text=True,
                timeout=Config.WHATIS_TIMEOUT
            )
            if not out or "nothing appropriate" in out:
                return None
            for line in out.splitlines():
                if line.strip().startswith(clean + "(") or line.strip().startswith(clean + " "):
                    parts = re.split(r"\s+[–-]\s+", line, maxsplit=1)
                    if len(parts) > 1:
                        return parts[1].strip()[:80]
        except Exception:
            pass
        return None

    def _extract_from_path(self, cmd, name):
        if not cmd:
            return None
        m = re.search(r"/([^/]+)\.app/", cmd)
        if m:
            return f"Active component of {m.group(1)}"
        if cmd.startswith(("/System/", "/usr/")):
            return None
        return None
```
