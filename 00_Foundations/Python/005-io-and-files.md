open
read
write
context manager
with
path

---

# open

- `open(path, mode, encoding=...)` — returns file object.
- Modes: `r` (read), `w` (write, truncate), `a` (append), `x` (create, fail if exists).
- Add `b` for binary: `rb`, `wb`; add `+` for read+write: `r+`.
- Default encoding: UTF-8 (Python 3); specify `encoding="utf-8"` for portability.

```python
f = open("file.txt", "r", encoding="utf-8")
content = f.read()
f.close()
```

# read, write

- `read()` — entire file; `read(n)` — n bytes.
- `readline()` — one line (includes `\n`).
- `readlines()` — list of lines.
- `write(s)` — write string; returns chars written.
- `writelines(iterable)` — write multiple lines (no newlines added).
- Files are iterable: `for line in f` reads line by line (memory efficient).

```python
with open("file.txt") as f:
    lines = f.readlines()  # list with \n

with open("out.txt", "w") as f:
    f.write("line1\n")
    f.writelines(["line2\n", "line3\n"])
```

# Context Manager (with)

- Automatically closes file; handles exceptions.
- Multiple: `with open(a) as f1, open(b) as f2:`

```python
with open("file.txt", "r") as f:
    content = f.read()
# f closed here, even if exception
```

# Path

- `pathlib.Path` — object-oriented path handling (Python 3.4+).
- Cross-platform; use `/` in code, Path handles OS differences.

```python
from pathlib import Path
p = Path("dir/file.txt")
p.read_text()           # read as str
p.write_text("content") # write str
p.read_bytes()         # read as bytes
p.exists()
p.is_file() / p.is_dir()
p.parent                # directory
p.name                  # filename
p.suffix                # extension
list(p.parent.iterdir()) # list directory
p / "sub" / "file.txt"  # join paths
```

# Common Patterns

```python
# Read lines (memory efficient)
with open("file.txt") as f:
    for line in f:
        process(line.rstrip())

# Read entire file as string
text = Path("file.txt").read_text()

# Read JSON
import json
data = json.load(open("file.json"))

# Write JSON
json.dump(data, open("out.json", "w"), indent=2)
```
