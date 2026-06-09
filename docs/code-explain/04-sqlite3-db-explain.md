modules/database.py


### A summary of what each method in the `ProcessCache` class does:

- `__init__`: Initializes the database table if it doesn't exist and connects to the database.
- `_init_db`: Creates a table named `process_cache` in the database if it doesn't exist.
- `get`: Retrieves the description, category, and source of a process from the database based on its name.
- `set`: Inserts or updates a process record in the database with the given name, description, category, source, and timestamps.

### /explain `__init__`

```python
    def __init__(self):
        Config.ensure_db_dir()
        self._init_db()
```

This code snippet defines the `__init__` method of the `ProcessCache` class. It calls the `ensure_db_dir` method from the `Config` class to ensure that the database directory exists. Then, it calls the `_init_db` method to initialize the database table if it doesn't already exist.

### /explain `_init_db`

```python title:'_init_db method'
    def _init_db(self):
        conn = sqlite3.connect(str(Config.DB_PATH))
        c = conn.cursor()
        c.execute("""
            CREATE TABLE IF NOT EXISTS process_cache (
                name        TEXT PRIMARY KEY,
                description TEXT,
                category    TEXT,
                source      TEXT,
                first_seen  TEXT,
                last_seen   TEXT,
                times_seen  INTEGER DEFAULT 1
            )
        """)
        conn.commit()
        conn.close()
```

This code snippet defines a private method `_init_db` within a class. 

It connects to a SQLite database using the path specified in `Config.DB_PATH`. 

Example usage: `{python title:'DB Path & File' icon}connection = sqlite3.connect('example.db')`

It then creates a table named `process_cache` if it doesn't already exist. 

The table has several columns: 
`name`, `description`, `category`, `source`, `first_seen`, `last_seen`, and `times_seen`. 

The `name` column is set as the primary key. 

The method commits the changes to the database and then closes the connection.

### /explain `get`

```python icon title:'get method'

    def get(self, name):
        conn = sqlite3.connect(str(Config.DB_PATH))
        c = conn.cursor()
        c.execute(
            "SELECT description, category, source FROM process_cache WHERE name = ?",
            (name,),
        )
        row = c.fetchone()
        conn.close()
        if row:
            return {"description": row[0], "category": row[1], "source": row[2]}
        return None
```

This code snippet defines a method called `get` in the `ProcessCache` class. 

It takes a `name` parameter and performs a database query to **retrieve** a row from a table called `process_cache` based on the provided `name`. 

The query selects the `description`, `category`, and `source` columns from the table. 

If a row is found, it returns a dictionary with the values from the row. 

If no row is found, it returns `None`. 

The database connection is established using the `sqlite3.connect` function and closed at the end of the method.

### /explain `set`

```python icon title:'set method'
    def set(self, name, description, category, source):
        now = datetime.now().isoformat()
        conn = sqlite3.connect(str(Config.DB_PATH))
        c = conn.cursor()
        c.execute(
            """INSERT INTO process_cache (name, description, category, source, first_seen, last_seen, times_seen)
               VALUES (?, ?, ?, ?, ?, ?, 1)
               ON CONFLICT(name) DO UPDATE SET
                   description = excluded.description,
                   category = excluded.category,
                   source = excluded.source,
                   last_seen = excluded.last_seen,
                   times_seen = times_seen + 1""",
            (name, description, category, source, now, now),
        )
        conn.commit()
        conn.close()
```

This code snippet defines a method called `set` that **inserts** a new row into a SQLite database table named `process_cache`. 

The method takes four parameters: `name`, `description`, `category`, and `source`. 

It uses the `datetime` module to get the current date and time and stores it in the `now` variable. 

It then establishes a connection to the SQLite database using the `sqlite3` module and creates a cursor object. 

The `execute` method is used to execute an SQL statement that inserts a new row into the `process_cache` table with the provided values. 

If a row with the same `name` already exists, the SQL statement updates the existing row with the new values. 

The `commit` method is called to save the changes to the database, and then the connection is closed.
