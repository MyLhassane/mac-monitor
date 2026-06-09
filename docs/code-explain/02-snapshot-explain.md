modules/snapshot.py

This class definition `ProcessSnapshot` contains a single static method `capture()`. 

The `capture()` method captures the current system processes by executing the `ps -A -o pid,%cpu,%mem,comm` command and parsing the output. It splits the output into lines, extracts the relevant information for each process (pid, cpu usage, memory usage, command), and creates a dictionary for each process. The method then returns a list of these dictionaries, representing the snapshot of the system processes.

Here's a breakdown of what each part of the method does:

- `subprocess.check_output()` executes the `ps -A -o pid,%cpu,%mem,comm` command and captures its output.
- `out.strip().split("\n")[1:]` splits the output into lines and removes the first line (header).
- `line.split(None, 3)` splits each line into parts based on the first three columns.
- `if len(parts) < 4: continue` skips any line that has fewer than four parts.
- `snapshot.append({...})` creates a dictionary for each process and appends it to the `snapshot` list.
- `"pid": int(parts[0]), "cpu": float(parts[1]), "mem": float(parts[2]), "cmd": parts[3].strip(), "name": os.path.basename(parts[3].strip()), "desc": None, "category": None, "source": None, "resolved": False` populates the dictionary with the relevant information for each process.

Overall, this class provides a convenient way to capture and process system process information.
