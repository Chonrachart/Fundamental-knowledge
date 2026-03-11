overview of

    interpreter
    execution
    REPL
    indentation
    shebang

---

# Interpreter

- Python is interpreted; no separate compile step for typical use.
- Bytecode (`.pyc`) may be cached for faster startup.
- Run with `python3` or `python` (system-dependent; prefer `python3` on Linux).
- Version: `python3 --version`.

### Virtual Environment

- Isolate project dependencies: `python3 -m venv myenv`
- Activate: `source myenv/bin/activate` (Linux/Mac) or `myenv\Scripts\activate` (Windows)
- Deactivate: `deactivate`

# Execution

- Run script: `python3 script.py`
- Interactive: `python3` (REPL).
- Module: `python3 -m module_name` (runs module as script).
- One-liner: `python3 -c "print('hello')"`

```bash
python3 script.py
python3 -m http.server 8000
python3 -c "print(2 + 2)"
```

# REPL

- Read-Eval-Print Loop; interactive shell.
- Type expressions; see result immediately.
- `_` holds last result; `help(obj)` for documentation.
- Exit: `exit()` or Ctrl-D.

```python
>>> 2 + 2
4
>>> _
4
>>> help(str)
```

# Indentation

- Python uses indentation for blocks; no braces.
- Standard: 4 spaces per level (PEP 8).
- Mixing tabs and spaces causes `TabError`.
- Same block must use same indentation.

```python
if True:
    print("indented")
    if nested:
        print("more")
```

# Shebang

- For executable scripts: `#!/usr/bin/env python3`
- Make executable: `chmod +x script.py`

```python
#!/usr/bin/env python3
print("Hello")
```

### Encoding (Python 3)

- Source files are UTF-8 by default.
- Declare encoding: `# -*- coding: utf-8 -*-` (only if needed)

# Topic Map

- [001-variables-and-types](./001-variables-and-types.md) — Variables, types, dynamic typing
- [002-control-flow](./002-control-flow.md) — if, for, while, match
- [003-functions](./003-functions.md) — def, args, return
- [004-data-structures](./004-data-structures.md) — list, dict, tuple, set
- [005-io-and-files](./005-io-and-files.md) — open, read, write, context manager
- [006-errors-and-exceptions](./006-errors-and-exceptions.md) — try, except, raise
- [007-modules-and-imports](./007-modules-and-imports.md) — import, module, package
