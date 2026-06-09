modules/snapshot.py

```python
import os
import subprocess


class ProcessSnapshot:
    @staticmethod
    def capture():
        out = subprocess.check_output(
            "ps -A -o pid,%cpu,%mem,comm", shell=True, text=True
        )
        lines = out.strip().split("\n")[1:]
        snapshot = []
        for line in lines:
            parts = line.split(None, 3)
            if len(parts) < 4:
                continue
            snapshot.append({
                "pid": int(parts[0]),
                "cpu": float(parts[1]),
                "mem": float(parts[2]),
                "cmd": parts[3].strip(),
                "name": os.path.basename(parts[3].strip()),
                "desc": None,
                "category": None,
                "source": None,
                "resolved": False,
            })
        return snapshot
```
