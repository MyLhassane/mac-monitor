modules/classifier.py
```python
from .config import Config


class ProcessClassifier:
    @classmethod
    def classify(cls, name, cmd):
        if name in Config.KNOWN_CLASSES:
            return Config.KNOWN_CLASSES[name]

        if cmd and ".app/" in cmd:
            return "USER_APP"

        if name.startswith("com.apple."):
            return "BACKGROUND_SERVICE"

        if name.endswith("d") and "Helper" not in name:
            return "BACKGROUND_SERVICE"

        if name in ("Finder", "Dock", "Terminal", "iTerm2", "WezTerm",
                     "Activity Monitor", "Console"):
            return "USER_APP"

        if cmd and "/usr/libexec/" in cmd:
            return "BACKGROUND_SERVICE"

        return "USER_APP"
```