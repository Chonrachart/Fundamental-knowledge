# Errors and Exceptions

- Python uses exceptions to signal errors; unhandled exceptions terminate the program with a traceback.
- `try/except` catches exceptions; `else` runs on success; `finally` always runs for cleanup.
- The exception hierarchy starts at `BaseException`; catch `Exception` for most errors, never `BaseException` (catches `KeyboardInterrupt`, `SystemExit`).

# Architecture

```text
Exception propagation through the call stack:

  main()  calls -->  process()  calls -->  parse()
                                             |
                                        raise ValueError
                                             |
                          No except here <---+
                               |
          except ValueError <--+    (caught here)
               |
          handler runs, program continues

  If NO handler found anywhere in the stack:
      --> interpreter prints traceback and exits
```

```text
Exception class hierarchy (simplified):

  BaseException
    +-- SystemExit
    +-- KeyboardInterrupt
    +-- Exception
          +-- ValueError
          +-- TypeError
          +-- KeyError
          +-- IndexError
          +-- FileNotFoundError
          +-- AttributeError
          +-- RuntimeError
          +-- ...
```

# Mental Model

```text
try/except/else/finally execution flow:

  try block
    |
    +-- exception raised?
    |       |
    |      YES --> matching except block runs
    |       |         |
    |       |         v
    |       |      finally block runs
    |       |
    |      NO
    |       |
    |       v
    |    else block runs (no exception)
    |       |
    |       v
    |    finally block runs
    |
    v
  continue after try statement
```

```python
# concrete example: safe file reading with full try structure
try:
    f = open("config.json")
except FileNotFoundError:
    print("Config not found, using defaults")
else:
    data = f.read()       # only runs if open succeeded
    f.close()
finally:
    print("Attempted config load")  # always runs
```

# Core Building Blocks

### try/except

- Catch exceptions to prevent crashes.
- Match first matching `except`; order matters (specific before general).

```python
try:
    result = int("abc")
except ValueError:
    print("Invalid input")
except TypeError:
    print("Wrong type")
```

Related notes: [005-io-and-files](./005-io-and-files.md)
- Order `except` blocks from most specific to most general.

### Exception Types

- Catch specific: `except ValueError:`.
- Catch multiple: `except (ValueError, TypeError):`.
- Catch all: `except Exception:` (use sparingly; can hide bugs).
- Get exception object: `except ValueError as e:` -- `e` has message, `e.args`.

```python
try:
    int("x")
except ValueError as e:
    print(e)      # invalid literal for int()
```

Related notes: [008-classes-and-oop](./008-classes-and-oop.md)
- `except Exception as e:` captures the exception object; `e.args` holds the arguments.

### raise

- Raise exception: `raise ValueError("message")`.
- Re-raise current exception: `raise` (no argument) -- preserves original traceback.

```python
if n < 0:
    raise ValueError("n must be non-negative")

try:
    risky()
except SomeError:
    log_error()
    raise  # re-raise for caller
```

Related notes: [003-functions](./003-functions.md)
- `raise` with no argument re-raises the current exception preserving the traceback.

### else and finally

- `else` -- runs only if no exception occurred in `try`.
- `finally` -- always runs (even on `return` or exception); use for cleanup.

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

Related notes: [002-control-flow](./002-control-flow.md), [005-io-and-files](./005-io-and-files.md)
- `finally` runs even if `return` is inside `try` or `except`.

### Exception Hierarchy

- `BaseException` -> `Exception` -> specific exceptions.
- Catch `Exception` for most built-in errors.
- Avoid `except BaseException` -- catches `KeyboardInterrupt`, `SystemExit`.

| Exception          | When                          |
| :----------------- | :---------------------------- |
| ValueError         | Bad value (e.g. `int("x")`)   |
| TypeError          | Wrong type                    |
| KeyError           | Missing dict key              |
| IndexError         | List index out of range       |
| FileNotFoundError  | File does not exist           |
| AttributeError     | Missing attribute on object   |
| RuntimeError       | Generic runtime error         |

Related notes: [008-classes-and-oop](./008-classes-and-oop.md)
- Never use bare `except:` or `except BaseException:` -- catches `KeyboardInterrupt` and `SystemExit`.
- Custom exceptions should inherit from `Exception`, not `BaseException`.

### Traceback
- Stack trace printed when an exception is unhandled; shows the call chain bottom-up.
- `traceback.print_exc()` -- print current exception to stderr.
- `traceback.format_exc()` -- return traceback as string (useful for logging).
- `try/except` catches exceptions; `else` runs on success; `finally` always runs.
- Traceback reads bottom-up: the last line is the exception, lines above show the call chain.
