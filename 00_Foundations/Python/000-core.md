# Python

- Python is a high-level, dynamically typed, interpreted language; source code is compiled to bytecode and executed by the Python Virtual Machine (PVM).
- The interpreter reads `.py` files, compiles them to `.pyc` bytecode, and the PVM executes that bytecode instruction by instruction.
- Key property: indentation defines code blocks (no braces); the standard library is extensive ("batteries included").

# Architecture

```text
+------------------+     +------------------+     +------------------+     +----------+
|   Source code    | --> |    Compiler      | --> |   PVM / Interp   | --> |  Output  |
|   (.py file)     |     | (to bytecode)    |     | (executes .pyc)  |     |          |
+------------------+     +------------------+     +------------------+     +----------+
                               |
                               v
                        +------------------+
                        | Cached bytecode  |
                        | (.pyc in         |
                        |  __pycache__/)   |
                        +------------------+

Execution modes:
  python3 script.py          run a script
  python3 -m module          run a module as __main__
  python3 -c "expr"          run a one-liner
  python3                    start interactive REPL
```

# Mental Model

```text
[1] Write source code (.py)
     |
     v
[2] Interpreter compiles to bytecode (.pyc, cached in __pycache__/)
     |
     v
[3] PVM executes bytecode line by line
     |
     v
[4] Output / side effects
```

```bash
# trace the full cycle: write, run, inspect cached bytecode
echo 'print("hello")' > demo.py
python3 demo.py
ls __pycache__/          # bytecode cache appears after import, not direct run
python3 -c "import demo" # triggers .pyc creation
ls __pycache__/
```

# Core Building Blocks

### Interpreter and Execution

- Python is interpreted; no separate compile step for typical use.
- Bytecode (`.pyc`) is cached in `__pycache__/` for faster startup on subsequent imports.
- Run with `python3` (prefer `python3` explicitly on Linux); check version with `python3 --version`.
- Execution modes: script (`python3 script.py`), module (`python3 -m name`), one-liner (`python3 -c "..."`), interactive REPL.
- Shebang for executable scripts: `#!/usr/bin/env python3` then `chmod +x script.py`.
- Source files are UTF-8 by default in Python 3; declare encoding with `# -*- coding: utf-8 -*-` only if needed.

Related notes: none (covered here)

### Virtual Environments

- Isolate project dependencies from the system Python: `python3 -m venv myenv`.
- Activate: `source myenv/bin/activate` (Linux/Mac) or `myenv\Scripts\activate` (Windows).
- Deactivate: `deactivate`.
- Always use a venv per project to avoid dependency conflicts.

Related notes: none (covered here)

### REPL

- Read-Eval-Print Loop; interactive shell launched with `python3`.
- Type expressions and see results immediately; `_` holds the last result.
- `help(obj)` for documentation, `dir(obj)` to list attributes.
- Exit: `exit()` or Ctrl-D.

Related notes: none (covered here)

### Indentation and Syntax

- Python uses indentation (not braces) to define code blocks.
- Standard: 4 spaces per level (PEP 8).
- Mixing tabs and spaces causes `TabError`.
- All statements in the same block must share the same indentation level.

Related notes: none (covered here)

### Variables and Types

- Variables are names bound to objects; no type declaration needed (dynamic typing).
- Common built-in types: `int`, `float`, `str`, `bool`, `None`.
- Type checking at runtime; use `type()` and `isinstance()` to inspect.
- Everything in Python is an object.

Related notes: [001-variables-and-types](./001-variables-and-types.md)

### Control Flow

- Branching: `if`, `elif`, `else`.
- Loops: `for` (iterate over sequences), `while` (condition-based).
- Pattern matching: `match`/`case` (Python 3.10+).
- Loop control: `break`, `continue`, `else` clause on loops.

Related notes: [002-control-flow](./002-control-flow.md)

### Functions

- Define with `def name(params):`, return with `return`.
- Arguments: positional, keyword, default, `*args`, `**kwargs`.
- Anonymous functions: `lambda x: x + 1`.
- Scope follows LEGB rule: Local, Enclosing, Global, Built-in.

Related notes: [003-functions](./003-functions.md)

### Data Structures

- `list` -- ordered, mutable sequence; `tuple` -- ordered, immutable sequence.
- `dict` -- key-value mapping; `set` -- unordered collection of unique elements.
- Comprehensions: `[x for x in iterable]`, `{k: v for ...}`, `{x for ...}`.
- Choose by need: mutability, ordering, uniqueness, key access.

Related notes: [004-data-structures](./004-data-structures.md)

### I/O and Files

- Open files with `open(path, mode)` inside a `with` statement (context manager).
- Modes: `r` (read), `w` (write/truncate), `a` (append), `rb`/`wb` (binary).
- `pathlib.Path` provides an object-oriented interface for filesystem operations.
- `print()` writes to stdout; `input()` reads from stdin.

Related notes: [005-io-and-files](./005-io-and-files.md)

### Errors and Exceptions

- Handle errors with `try` / `except` / `else` / `finally`.
- Raise exceptions explicitly with `raise`.
- Built-in hierarchy: `BaseException` > `Exception` > specific exceptions.
- Catch specific exceptions; avoid bare `except:`.

Related notes: [006-errors-and-exceptions](./006-errors-and-exceptions.md)

### Modules and Imports

- A module is a `.py` file; a package is a directory with `__init__.py`.
- Import with `import module`, `from module import name`, or `import module as alias`.
- `__name__ == "__main__"` guard separates importable code from script execution.
- Standard library provides extensive built-in modules (`os`, `sys`, `json`, `pathlib`, etc.).

Related notes: [007-modules-and-imports](./007-modules-and-imports.md)

### Classes and OOP

- Define with `class Name:`, instantiate with `Name()`.
- `__init__` is the constructor; `self` refers to the instance.
- Supports inheritance, multiple inheritance, and method resolution order (MRO).
- Dunder methods (`__str__`, `__repr__`, `__len__`, etc.) customize object behavior.

Related notes: [008-classes-and-oop](./008-classes-and-oop.md)

### Decorators and Generators

- Decorators wrap functions to add behavior: `@decorator` syntax.
- Common built-in decorators: `@staticmethod`, `@classmethod`, `@property`.
- Generators use `yield` to produce values lazily, one at a time.
- Generator expressions: `(x for x in iterable)` -- memory-efficient iteration.

Related notes: [009-decorators-and-generators](./009-decorators-and-generators.md)

---

# Practical Command Set (Core)

```bash
# check Python version
python3 --version

# run a script
python3 script.py

# run a module as script
python3 -m http.server 8000

# run a one-liner
python3 -c "print('hello')"

# create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# install packages in venv
pip install requests
pip freeze > requirements.txt
pip install -r requirements.txt

# make script executable
chmod +x script.py
./script.py              # requires shebang line

# check syntax without running
python3 -m py_compile script.py

# run with warnings enabled
python3 -W all script.py
```

# Troubleshooting Flow (Quick)

```text
Problem: Python script fails or behaves unexpectedly
    |
    v
[1] Version: are you running the right Python?
    python3 --version / which python3
    |
    v
[2] Environment: is the correct venv activated?
    which pip / pip list
    |
    v
[3] Syntax: any SyntaxError or IndentationError?
    python3 -m py_compile script.py
    |
    v
[4] Import: ModuleNotFoundError?
    pip list | grep <package> / pip install <package>
    |
    v
[5] Runtime: read the traceback bottom-up
    last line = exception type + message
    line above = file, line number, function
    |
    v
[6] Logic: add print() or use pdb
    python3 -m pdb script.py
```

# Quick Facts (Revision)

- Python is interpreted but compiles to bytecode (.pyc) cached in `__pycache__/`.
- Indentation (4 spaces) defines blocks; mixing tabs and spaces raises `TabError`.
- Everything is an object; variables are names bound to objects (dynamic typing).
- `python3 -m venv env` creates an isolated environment; always use one per project.
- LEGB scope rule: Local > Enclosing > Global > Built-in.
- `with` statement manages resources (files, locks) via context managers.
- `__name__ == "__main__"` guard separates reusable modules from script entry points.
- PEP 8 is the style guide; enforce with `flake8` or `ruff`.

# Topic Map

- [001-variables-and-types](./001-variables-and-types.md) -- Variables, types, dynamic typing
- [002-control-flow](./002-control-flow.md) -- if, for, while, match
- [003-functions](./003-functions.md) -- def, args, lambda, scope
- [004-data-structures](./004-data-structures.md) -- list, dict, tuple, set, comprehension
- [005-io-and-files](./005-io-and-files.md) -- open, read, write, pathlib
- [006-errors-and-exceptions](./006-errors-and-exceptions.md) -- try, except, raise
- [007-modules-and-imports](./007-modules-and-imports.md) -- import, package, __name__
- [008-classes-and-oop](./008-classes-and-oop.md) -- class, inheritance, dunder methods
- [009-decorators-and-generators](./009-decorators-and-generators.md) -- decorators, generators, iterators
