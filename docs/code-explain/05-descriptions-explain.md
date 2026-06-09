modules/descriptions.py

This class, `DescriptionResolver`, is used to resolve descriptions for processes based on their names and commands. 
Here's a summary of what each method does:

- `{python icon} __init__(self, cache=None)`: 
  
  Initializes an instance of the class with an optional cache object. 
  If no cache is provided, it uses a default `ProcessCache`.

- `{python icon} resolve_immediate(self, name, cmd, category)`: 
  
  This method resolves the description immediately for a given process name and command. 
  It first checks if the description is already cached. 
  If not, it checks for hardcoded overrides. 
  If not found, it tries to extract a description from the command path. 
  If all else fails, it returns `None`.

- `{python icon} resolve_background(self, name, cmd, description, category, source)`: 
  
  This method sets the description, category, and source in the cache for a given process name, command, description, category, and source.

- `{python icon} _try_whatis(self, name)`:
  
 This method tries to get a description for a process name using the `whatis` command. It cleans the name, runs the `whatis` command, and extracts the description from the output.

- `{python icon} _extract_from_path(self, cmd, name)`: 
  
  This method tries to extract a description from the command path. 
  It checks if the command contains a `.app/` path and returns a specific message if found.
  It also checks if the command starts with `/System/` or `/usr/` and returns `None` in that case.

---

### /explain `__init__`

```python title:
    def __init__(self, cache=None):
        self.cache = cache or ProcessCache()
```

This code snippet defines the constructor (`__init__`) of a class called `DescriptionResolver`. It initializes an instance variable called `cache` with the value passed as an argument. 
If no argument is provided, it initializes `cache` with an instance of the `ProcessCache` class.

### /explain `resolve_immediate`

```python title:'resolve_immediate method'
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
```

This code snippet defines a method called `resolve_immediate` in the `DescriptionResolver` class. 

The method takes in four parameters: 
`name`, `cmd`, and `category`, and it has a return type of tuple. 

The method first checks if the `name` exists in the cache. 
If it does, it returns the cached description, category, and source.

If the `name` is present in the `Config.HARDCODED_OVERRIDES` dictionary, it retrieves the corresponding description from there, sets it in the cache, and returns it along with the category and source.

If none of the above conditions are met, it calls the `_extract_from_path` method with the `cmd` and `name` parameters, and if a description is extracted, it sets it in the cache and returns it along with the category and source.

If none of the above conditions are met, it returns `None` for the description, the provided category, and `None` for the source.

### /explain `resolve_background`

```python title:'resolve_background method'
    def resolve_background(self, name, cmd, description, category, source):
        self.cache.set(name, description, category, source)
```

This code snippet defines a method called `resolve_background` in the `DescriptionResolver` class. 

It takes in several parameters: 

`name`, `cmd`, `description`, `category`, and `source`. 

Inside the method, it calls the `set` method of the `cache` object, passing in the `name`, `description`, `category`, and `source` as arguments. 

This method is used to store the description of a process in the cache, along with its category and source.

### /explain `_try_whatis`

```python title'_try_whatis method'
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
```

This code snippet defines a private method `_try_whatis` within the `DescriptionResolver` class. It takes a `name` parameter and attempts to retrieve a description for the process with that name using the `whatis` command. 

Here's a breakdown of what the code does:

1. It removes any content within parentheses from the `name` using regular expressions and splits it into words. It then takes the first word as `clean`.
2. If `clean` is empty or has less than 2 characters, it returns `None`.
3. It tries to execute the `whatis` command with `clean` as an argument using `subprocess.check_output()`. The output of the command is captured and stored in `out`.
4. If `out` is empty or contains the string "nothing appropriate", it returns `None`.
5. It iterates over each line in `out` and checks if the line starts with `clean` followed by an opening parenthesis or a space. If it does, it splits the line at the first occurrence of a hyphen followed by one or more spaces and checks if there are more than one part.
6. If there are more than one part, it returns the second part (description) after removing leading and trailing whitespace and limiting its length to 80 characters.
7. If any exception occurs during the execution of the `whatis` command, it is caught and ignored.
8. If none of the above conditions are met, it returns `None`.

### /explain `_extract_from_path`

```python title'_extract_from_path method
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

This code snippet defines a method `_extract_from_path` that takes in three parameters: `self`, `cmd`, and `name`. 

The method first checks if the `cmd` parameter is empty, and if so, it returns `None`. 

Then, it uses a regular expression to search for a pattern in the `cmd` string. If the pattern is found, it returns a formatted string that includes the matched group from the pattern. 

If the `cmd` string starts with either `"/System/"` or `"/usr/"`, the method returns `None`. 

If none of the above conditions are met, the method also returns `None`.