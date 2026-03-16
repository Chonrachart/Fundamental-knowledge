# Modules and Imports

- A module is any `.py` file; a package is a directory with `__init__.py` containing modules.
- `import` loads and caches a module once; `from ... import` pulls specific names into the current namespace.
- Python resolves imports by searching `sys.modules` cache first, then directories in `sys.path` (script dir, PYTHONPATH, install defaults).

# Architecture

```text
Import resolution pipeline:

  import mymodule
       |
       v
  +-------------------+
  | sys.modules cache  |---> found? --> return cached module
  +-------------------+
       |
       not found
       |
       v
  +-------------------+
  | sys.path search    |---> search each directory in order:
  |                    |       1. script directory (or cwd)
  |                    |       2. PYTHONPATH entries
  |                    |       3. site-packages (pip installs)
  +-------------------+
       |
       found .py file (or package dir)
       |
       v
  +-------------------+
  | Load and compile   |---> compile to bytecode (.pyc in __pycache__)
  +-------------------+
       |
       v
  +-------------------+
  | Execute module     |---> run top-level code in module
  +-------------------+
       |
       v
  +-------------------+
  | Cache in           |---> store in sys.modules for future imports
  | sys.modules        |
  +-------------------+
```

# Mental Model

```text
Import decision tree:

  Need to use external code?
    |
    +-- entire module ---------> import os
    |                            os.path.join(...)
    |
    +-- specific name ----------> from os import path
    |                             path.join(...)
    |
    +-- with alias -------------> import numpy as np
    |                             np.array(...)
    |
    +-- inside a package -------> from . import utils        (relative)
    |                             from ..sibling import func (relative)
    |
    +-- avoid -------------------> from module import *      (pollutes namespace)
```

```python
# concrete example: script that works both as module and standalone
def greet(name):
    return f"Hello, {name}"

if __name__ == "__main__":
    # only runs when executed directly: python mymodule.py
    print(greet("world"))
# when imported: __name__ == "mymodule", this block is skipped
```

# Core Building Blocks

### import

- Load module: `import module` or `import module as alias`.
- Module is loaded once; cached in `sys.modules`.
- Access via dot notation: `module.func()`.

```python
import os
os.path.join("a", "b")

import long_module_name as lm
lm.func()
```

Related notes: [003-functions](./003-functions.md)

### from import

- Import specific names: `from module import func`.
- Import all: `from module import *` (avoid; pollutes namespace; respects `__all__`).
- Alias: `from module import long_name as ln`.

```python
from os import path
from pathlib import Path
from mymodule import func1, func2
```

Related notes: [001-variables-and-types](./001-variables-and-types.md)

### Modules

- A `.py` file is a module; module name = filename without `.py`.
- Top-level code executes on first import; subsequent imports use cache.
- Location: `module.__file__` shows the file path.

Related notes: [005-io-and-files](./005-io-and-files.md)

### Packages

- A directory with `__init__.py` (or namespace package in Python 3.3+).
- Submodules accessed via dot notation: `package.submodule`.
- `__init__.py` runs when the package is imported; can be empty or define `__all__`.

```text
mypkg/
  __init__.py
  utils.py
  subpkg/
    __init__.py
    helper.py
```

```python
from mypkg.utils import helper
from mypkg.subpkg.helper import something
```

Related notes: [005-io-and-files](./005-io-and-files.md)

### Relative Imports

- Inside a package: `from . import utils` or `from ..parent import x`.
- `.` = current package, `..` = parent package.
- Only work inside packages; cannot be used in top-level scripts.

```python
# inside mypkg/subpkg/helper.py
from . import sibling_module       # same package
from .. import utils               # parent package
from ..other_subpkg import tool    # sibling package
```

Related notes: [008-classes-and-oop](./008-classes-and-oop.md)

### __name__ and __main__

- When run directly: `python script.py` -> `__name__ == "__main__"`.
- When imported: `__name__` is the module's qualified name (e.g. `"mypkg.utils"`).
- Use for separating script behavior from library behavior.

```python
def main():
    ...

if __name__ == "__main__":
    main()
```

Related notes: [003-functions](./003-functions.md)

### Search Path

- `sys.path` -- list of directories searched for imports, in order.
- First: script directory (or cwd), then `PYTHONPATH` env var, then installation defaults (site-packages).
- Add dynamically: `sys.path.insert(0, "/my/dir")` (avoid if possible; prefer proper packaging).

```python
import sys
print(sys.path)  # see where Python looks for modules
```

Related notes: [006-errors-and-exceptions](./006-errors-and-exceptions.md)

---

# Troubleshooting Flow (Quick)

```text
Problem: ModuleNotFoundError or ImportError
    |
    v
[1] Is the module installed?
    pip show <module>
    |
    +-- not installed --> pip install <module>
    |
    v
[2] Is the right Python/venv active?
    which python / python -m pip list
    |
    +-- wrong env --> activate correct venv
    |
    v
[3] Is the module on sys.path?
    python -c "import sys; print(sys.path)"
    |
    +-- directory missing --> check PYTHONPATH, script location
    |
    v
[4] Circular import?
    ImportError at runtime, not at first import
    |
    +-- yes --> move import inside function, or restructure modules
    |
    v
[5] Relative import error?
    "attempted relative import beyond top-level package"
    |
    +-- running script directly? --> use python -m package.module
    +-- missing __init__.py? --> add it to the package directory
```

# Quick Facts (Revision)

- A module is a `.py` file; a package is a directory with `__init__.py`.
- `import` loads once and caches in `sys.modules`; re-importing returns the cached version.
- `from module import *` is discouraged; it pollutes the namespace and makes code harder to trace.
- `sys.path` search order: script dir, PYTHONPATH, site-packages.
- `if __name__ == "__main__":` runs only when the file is executed directly, not when imported.
- Relative imports (`from . import x`) only work inside packages, not top-level scripts.
- Bytecode is cached in `__pycache__/` as `.pyc` files for faster subsequent imports.
- Use `python -m package.module` to run a module inside a package correctly.
