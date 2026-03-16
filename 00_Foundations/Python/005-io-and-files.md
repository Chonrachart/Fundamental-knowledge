# I/O and Files

- Python provides built-in `open()` for file I/O with mode control (read, write, append, binary).
- The `with` statement (context manager) guarantees files are closed even on exceptions.
- `pathlib.Path` offers cross-platform, object-oriented path manipulation and convenience read/write methods.

# Architecture

```text
+-------------------+
|   Python code     |   open(), read(), write(), pathlib
+-------------------+
        |
        v
+-------------------+
|   File object     |   buffered wrapper (TextIOWrapper / BufferedReader)
|   (mode, encoding)|
+-------------------+
        |
        v
+-------------------+
|   OS file         |   file descriptor (int), managed by kernel
|   descriptor      |   os.open(), os.read() (low-level)
+-------------------+
        |
        v
+-------------------+
|   Disk / Storage  |   actual bytes on filesystem
+-------------------+
```

# Mental Model

```text
Decision: read or write?

  Need to READ a file
    |
    +-- text mode ----> open("f.txt", "r", encoding="utf-8")
    |                      f.read() / for line in f
    +-- binary mode --> open("f.bin", "rb")
                           f.read()  (returns bytes)

  Need to WRITE a file
    |
    +-- overwrite -----> open("f.txt", "w")    truncates first
    +-- append --------> open("f.txt", "a")    writes at end
    +-- create only ---> open("f.txt", "x")    fails if exists
    +-- read+write ----> open("f.txt", "r+")   no truncation
```

```python
# concrete example: read a config, transform, write output
from pathlib import Path

config = Path("config.txt").read_text(encoding="utf-8")
lines = [line.upper() for line in config.splitlines()]
Path("config_upper.txt").write_text("\n".join(lines), encoding="utf-8")
```

# Core Building Blocks

### Opening Files

- `open(path, mode, encoding=...)` -- returns a file object.
- Modes: `r` (read), `w` (write, truncate), `a` (append), `x` (create, fail if exists).
- Add `b` for binary: `rb`, `wb`; add `+` for read+write: `r+`.
- Default encoding: UTF-8 (Python 3); specify `encoding="utf-8"` for portability.

```python
f = open("file.txt", "r", encoding="utf-8")
content = f.read()
f.close()
```

Related notes: [006-errors-and-exceptions](./006-errors-and-exceptions.md)

### Reading and Writing

- `read()` -- entire file; `read(n)` -- n bytes/chars.
- `readline()` -- one line (includes `\n`).
- `readlines()` -- list of lines.
- `write(s)` -- write string; returns chars written.
- `writelines(iterable)` -- write multiple lines (no newlines added automatically).
- Files are iterable: `for line in f` reads line by line (memory efficient).

```python
with open("file.txt") as f:
    lines = f.readlines()  # list with \n

with open("out.txt", "w") as f:
    f.write("line1\n")
    f.writelines(["line2\n", "line3\n"])
```

Related notes: [004-data-structures](./004-data-structures.md)

### Context Managers

- `with` statement automatically closes the file; handles exceptions.
- Multiple files: `with open(a) as f1, open(b) as f2:`.
- Preferred over manual `open()` / `close()` in all cases.

```python
with open("file.txt", "r") as f:
    content = f.read()
# f closed here, even if exception occurred
```

Related notes: [006-errors-and-exceptions](./006-errors-and-exceptions.md), [009-decorators-and-generators](./009-decorators-and-generators.md)

### pathlib

- `pathlib.Path` -- object-oriented path handling (Python 3.4+).
- Cross-platform; use `/` operator to join paths, Path handles OS differences.

```python
from pathlib import Path
p = Path("dir/file.txt")
p.read_text()           # read as str
p.write_text("content") # write str
p.read_bytes()          # read as bytes
p.exists()
p.is_file() / p.is_dir()
p.parent                # directory
p.name                  # filename
p.suffix                # extension
list(p.parent.iterdir()) # list directory
p / "sub" / "file.txt"  # join paths
```

Related notes: [007-modules-and-imports](./007-modules-and-imports.md)

### Common Patterns (JSON, Line Processing)

```python
# Read lines (memory efficient)
with open("file.txt") as f:
    for line in f:
        process(line.rstrip())

# Read entire file as string
text = Path("file.txt").read_text()

# Read JSON
import json
with open("file.json") as f:
    data = json.load(f)

# Write JSON
with open("out.json", "w") as f:
    json.dump(data, f, indent=2)
```

Related notes: [001-variables-and-types](./001-variables-and-types.md), [004-data-structures](./004-data-structures.md)

---

# Troubleshooting Flow (Quick)

```text
Problem: file operation fails or behaves unexpectedly
    |
    v
[1] FileNotFoundError?
    Path("file.txt").exists()
    |
    +-- False --> check path, cwd (os.getcwd()), spelling
    |
    v
[2] PermissionError?
    |
    +-- yes --> check file permissions (os.stat), user context
    |
    v
[3] Encoding errors (UnicodeDecodeError)?
    |
    +-- yes --> specify encoding explicitly: open(..., encoding="utf-8")
    |           or open in binary mode ("rb") and decode manually
    |
    v
[4] Data missing or truncated?
    |
    +-- opened with "w" instead of "a"? --> "w" truncates the file
    +-- forgot to flush/close? --> use "with" statement
    |
    v
[5] Check file object state
    f.closed, f.mode, f.name
```

# Quick Facts (Revision)

- `open()` modes: `r` read, `w` write (truncate), `a` append, `x` exclusive create; add `b` for binary, `+` for read+write.
- Always use `with open(...) as f:` -- guarantees close even on exception.
- `for line in f` is the most memory-efficient way to read lines.
- `pathlib.Path` is preferred over `os.path` for path manipulation in modern Python.
- `read()` loads the entire file into memory; avoid on large files.
- `writelines()` does not add newlines -- you must include `\n` in each string.
- JSON: `json.load(f)` reads from file object; `json.loads(s)` reads from string.
- Default encoding in Python 3 is platform-dependent; always specify `encoding="utf-8"` explicitly.
