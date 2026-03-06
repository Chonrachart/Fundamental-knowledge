try
except
raise
finally
Exception
traceback

---

# try, except

- Catch exceptions; prevent crash.
- Match first matching `except`; order matters (specific before general).

```python
try:
    result = int("abc")
except ValueError:
    print("Invalid input")
except TypeError:
    print("Wrong type")
```

# except Types

- Catch specific: `except ValueError:`.
- Catch multiple: `except (ValueError, TypeError):`.
- Catch all: `except Exception:` (use sparingly; can hide bugs).
- Get exception: `except ValueError as e:` — `e` has message, `e.args`.

```python
try:
    int("x")
except ValueError as e:
    print(e)      # invalid literal for int()
```

# raise

- Raise exception: `raise ValueError("message")`.
- Re-raise: `raise` (no argument) — preserves traceback.

```python
if n < 0:
    raise ValueError("n must be non-negative")

try:
    risky()
except SomeError:
    log_error()
    raise  # re-raise for caller
```

# else and finally

- `else` — runs if no exception in try.
- `finally` — always runs (even on return or exception); use for cleanup.

```python
try:
    f = open("file.txt")
except FileNotFoundError:
    print("Not found")
else:
    content = f.read()
finally:
    f.close()  # always close
```

# Exception Hierarchy

- `BaseException` → `Exception` → `ValueError`, `TypeError`, `KeyError`, `IndexError`, etc.
- Catch `Exception` for most built-in errors.
- Avoid `except BaseException` — catches `KeyboardInterrupt`, `SystemExit`.

| Exception     | When                          |
| :------------ | :---------------------------- |
| ValueError   | Bad value (e.g. int("x"))     |
| TypeError     | Wrong type                    |
| KeyError      | Missing dict key              |
| IndexError    | List index out of range      |
| FileNotFoundError | File does not exist      |

# Traceback

- Stack trace when exception occurs; shows call chain.
- `traceback.print_exc()` — print to stderr.
- `traceback.format_exc()` — return as string.

```python
import traceback
try:
    risky()
except Exception:
    traceback.print_exc()
```
