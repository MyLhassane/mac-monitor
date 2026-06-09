modules/config.py

This `Config` class defines a set of constants and a class method `ensure_db_dir`:

- Constants:
  - `DB_DIR`: The directory path for storing process cache data.
  - `DB_PATH`: The path to the process cache database file.
  - `GROQ_MODEL`, `GROQ_MAX_CONCURRENT`, `GROQ_DELAY_BETWEEN`, `GROQ_MAX_RETRIES`, `SNAPSHOT_MAX_PER_CATEGORY`, `UI_REFRESH_INTERVAL`, `WHATIS_TIMEOUT`: Various parameters used in the application.
  - `HARDCODED_OVERRIDES`: A dictionary mapping specific process names to their descriptions.
  - `KNOWN_CLASSES`: A dictionary mapping specific process names to their categories.

- `ensure_db_dir`: A class method that ensures the existence of the `DB_DIR` directory. If the directory does not exist, it will be created. If it already exists, it will be left unchanged.

---

```
@classmethod

def ensure_db_dir(cls):

cls.DB_DIR.mkdir(parents=True, exist_ok=True)
```

This code snippet defines a class method called `ensure_db_dir` in the `Config` class. This method ensures that the directory specified by `Config.DB_DIR` exists. If the directory does not exist, it creates it. The `parents=True` argument ensures that any parent directories are also created if they don't exist. The `exist_ok=True` argument allows the method to succeed even if the directory already exists.