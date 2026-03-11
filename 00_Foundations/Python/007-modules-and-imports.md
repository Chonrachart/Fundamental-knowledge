import
from
module
package
__name__
__main__

---

# import

- Load module: `import module` or `import module as m`.
- Module is loaded once; cached in `sys.modules`.
- Access: `module.func()`.

```python
import os
os.path.join("a", "b")

import long_module_name as lm
lm.func()
```

# from import

- Import specific names: `from module import func`.
- Import all: `from module import *` (avoid; pollutes namespace; not in `__all__`).
- Alias: `from module import long_name as ln`.

```python
from os import path
from pathlib import Path
from mymodule import func1, func2
```

# module

- A `.py` file is a module.
- Module name = filename without `.py`.
- Location: `module.__file__`.

# package

- Directory with `__init__.py` (or namespace package in Python 3.3+).
- Submodules: `package.submodule`.
- `__init__.py` runs when package is imported; can be empty.

```
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

### Relative Import

- Inside package: `from . import utils` or `from ..parent import x`.
- `.` = current package, `..` = parent package.

# __name__ and __main__

- When run directly: `python script.py` → `__name__ == "__main__"`.
- When imported: `__name__` is module name (e.g. `"mypkg.utils"`).
- Use for script vs library behavior.

```python
def main():
    ...

if __name__ == "__main__":
    main()
```

# Search Path

- `sys.path` — list of directories searched for imports.
- First: script directory, then `PYTHONPATH`, then installation default.
- Add: `sys.path.insert(0, "/my/dir")` (avoid if possible).
