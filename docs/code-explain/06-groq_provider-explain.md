modules/groq_provider.py

### /explain `GroqProvider`

The `GroqProvider` class is a provider for the Groq API, which is used to get descriptions for macOS process names. The class has the following methods:

- `__init__`: Initializes the provider by setting up the Groq client with an API key from environment variables or from a fallback if not found. It also sets up some internal variables for rate limiting and counting the number of daily requests.

- `describe`: Given a process name, it sends a request to the Groq API to get a description of the process. It uses rate limiting to ensure that the API is not called too frequently. If the daily limit is reached, it returns `None`. If the request is successful, it returns the description. If there is an error, it returns `None`.



### /explain `__init__`

```python title:'__init__ method'
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
```

This code snippet is the constructor of a class named `GroqProvider`. It initializes the `api_key` variable by trying to retrieve it from the environment variable `GROQ_API_KEY`. If it's not found, it tries to retrieve it from the environment variable `os.environ.get("GROQ_API_KEY")`. If it's still not found, it raises a `RuntimeError` with a message indicating that the `GROQ_API_KEY` is not found and should be set in the `.env` file or exported as an environment variable. 

After that, it creates an instance of the `Groq` class with the retrieved `api_key`, initializes a lock for thread safety, sets the `last_call` time to 0.0, and initializes the `daily_count` and `max_daily` variables to 0 and 14000, respectively.

### /explain `describe`

```python title:'describe method'
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
```

This code snippet defines a method called `describe` in a class. The method takes a parameter `name`. 

Inside the method, it first acquires a lock using `self._lock` to ensure thread safety. It then calculates the elapsed time since the last call to this method and checks if it is less than a specified delay time (`Config.GROQ_DELAY_BETWEEN`). If it is, it sleeps for the remaining time.

Next, it checks if the daily count of calls to this method has reached the maximum limit (`self.max_daily`). If it has, it returns `None`.

If none of the above conditions are met, it updates the last call time and increments the daily count.

After releasing the lock, it makes a request to an API (`self.client.chat.completions.create`) with specific parameters, including the `name` parameter as the content of the message. It expects a response with a `content` field in the first choice of the `choices` list. It then strips any leading and trailing whitespace and removes the trailing period from the content before returning it.

If any exception occurs during the API request, it returns `None`.
