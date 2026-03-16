# Variables and Types

- Every value in Python is an object on the heap; variables are just names that reference objects.
- Built-in types cover numerics (int, float, bool), text (str), collections (list, dict, tuple, set), and binary (bytes).
- Python is dynamically typed -- a name can refer to any type at any time; type hints add optional static checking.

# Architecture

```text
Python Object Model

  Source code              Runtime (heap)
  ----------              ---------------

  x = 42          name "x" ----+
                                |
                                v
                         +--------------+
                         | object       |
                         | type: int    |
                         | value: 42    |
                         | refcount: 1  |
                         +--------------+

  y = x           name "y" ----+
                                |
  (same object)   name "x" ----+
                                |
                                v
                         +--------------+
                         | object       |
                         | type: int    |
                         | value: 42    |
                         | refcount: 2  |
                         +--------------+

  x = "hello"     name "x" ----+
                                |
                                v
                         +--------------+
                         | object       |
                         | type: str    |
                         | value: hello |
                         | refcount: 1  |
                         +--------------+

                  name "y" ----+
                                |
                                v
                         +--------------+
                         | object       |
                         | type: int    |
                         | value: 42    |
                         | refcount: 1  |
                         +--------------+
```

# Mental Model

```text
Assignment creates references, not copies:

  [1] x = [1, 2, 3]    --> name "x" points to list object on heap
  [2] y = x             --> name "y" points to SAME list object
  [3] y.append(4)       --> list is [1, 2, 3, 4]
  [4] print(x)          --> [1, 2, 3, 4]  (x sees the change!)

  To get a separate copy:
  [5] z = x.copy()      --> new list object; z is independent
  [6] z.append(5)       --> x is still [1, 2, 3, 4]
```

```python
# concrete example
x = [1, 2, 3]
y = x             # y and x refer to same list
y.append(4)
print(x)           # [1, 2, 3, 4]

z = x.copy()       # z is an independent copy
z.append(5)
print(x)           # [1, 2, 3, 4] -- unchanged
print(z)           # [1, 2, 3, 4, 5]
```

# Core Building Blocks

### Variables and Assignment

- Name that refers to an object; no declaration needed.
- Create by assignment: `x = 10`.
- Names are case-sensitive: `name` and `Name` are different.
- `name = value` -- binds name to object.
- Multiple: `a, b = 1, 2` (tuple unpacking) or `a = b = 0` (same object).
- Swap: `a, b = b, a`.

```python
a, b = 1, 2
a, b = b, a  # swap
x = y = []   # both refer to same list
```

Related notes: [000-core](./000-core.md)

### Numeric Types (int, float, bool)

**int**

- Integer; arbitrary precision (no overflow).
- Literals: `42`, `0xff`, `0o10`, `0b1010`.
- Operators: `+`, `-`, `*`, `//` (floor div), `%`, `**`.
- `int("100")` -- parse string; `int("ff", 16)` -- parse with base (2-36).

```python
10 // 3    # 3
10 % 3     # 1
2 ** 10    # 1024
```

**float**

- Floating-point; IEEE 754 double precision.
- Literals: `3.14`, `1e6`, `2.5e-3`.
- Precision limits; use `decimal.Decimal` for exact decimal.
- `float("3.14")` -- parse string.
- `math.isclose(a, b)` for approximate equality.

```python
0.1 + 0.2  # 0.30000000000000004 (precision)
```

**bool**

- Boolean; `True` or `False`.
- Subclass of `int`: `True == 1`, `False == 0`.
- Falsy: `False`, `None`, `0`, `0.0`, `""`, `[]`, `{}`, `()`, `set()`.
- `bool(x)` -- truth value of x.

Related notes: [002-control-flow](./002-control-flow.md)

### Strings (str)

- Immutable sequence of Unicode characters.
- Literals: `'...'`, `"..."`, `'''...'''`, `"""..."""`.
- Raw: `r'\n'` -- backslash literal (no escape).
- f-string: `f"x={x}"` -- interpolate; `f"{x:.2f}"` -- format.

**Common str methods**

- `s.upper()`, `s.lower()`, `s.strip()`, `s.split()`, `s.join()`
- `s.startswith()`, `s.endswith()`, `s.replace()`, `s.find()`, `s.index()`
- `s.format()`, `s.encode()` -- to bytes

```python
"  hello  ".strip()       # "hello"
"a,b,c".split(",")       # ["a", "b", "c"]
",".join(["a", "b"])     # "a,b"
"hello".replace("l", "x") # "hexxo"
```

Related notes: [005-io-and-files](./005-io-and-files.md)

### Collections Overview (list, dict, tuple, set, bytes)

**list** -- ordered, mutable sequence.

- Literal: `[1, 2, 3]`.
- Index: `lst[0]`, `lst[-1]`; slice: `lst[1:3]`.
- Methods: `append`, `extend`, `insert`, `remove`, `pop`, `sort`, `reverse`, `index`, `count`.
- `len(lst)`, `x in lst`.

**dict** -- key-value mapping; keys must be hashable (immutable).

- Literal: `{"a": 1, "b": 2}`.
- Access: `d[key]`, `d.get(key, default)`.
- Methods: `keys()`, `values()`, `items()`, `setdefault()`, `pop()`.
- `len(d)`, `key in d`.

**tuple** -- ordered, immutable sequence.

- Literal: `(1, 2, 3)` or `1, 2, 3`; single: `(1,)`.
- Use for fixed data, return multiple values, dict keys.
- Methods: `index`, `count`; no mutating methods.

**set** -- unordered, unique elements; no duplicates; no index.

- Literal: `{1, 2, 3}`; empty: `set()` (not `{}`).
- Methods: `add`, `remove`, `discard`, `union`, `intersection`, `difference`.
- Operators: `|`, `&`, `-`, `^` (symmetric diff).
- Hashable elements only.

**bytes** -- immutable sequence of bytes (0-255).

- Literal: `b'hello'`, `bytes([65, 66, 67])`.
- `str.encode()` -> bytes; `bytes.decode()` -> str.
- Use for binary data, file I/O in binary mode.

```python
"hello".encode()      # b'hello'
b'hello'.decode()    # "hello"
```

**Type summary table**

| Type   | Mutable | Ordered    | Duplicates | Literal / Create  |
| :----- | :------ | :--------- | :--------- | :---------------- |
| int    | --      | --         | --         | `42`              |
| float  | --      | --         | --         | `3.14`            |
| bool   | --      | --         | --         | `True`, `False`   |
| str    | No      | Yes        | Yes        | `"..."`           |
| list   | Yes     | Yes        | Yes        | `[1, 2, 3]`      |
| dict   | Yes     | Yes (3.7+) | No keys    | `{"a": 1}`        |
| tuple  | No      | Yes        | Yes        | `(1, 2, 3)`      |
| set    | Yes     | No         | No         | `{1, 2, 3}`      |
| bytes  | No      | Yes        | Yes        | `b"..."`          |

Related notes: [004-data-structures](./004-data-structures.md)

### Dynamic Typing

- Variable can refer to different types over time.
- Type is determined at runtime, not declaration.
- Use `isinstance()` for type checks in code.
- Check type: `type(x)` or `isinstance(x, int)`.
- Convert: `int()`, `str()`, `float()`, `list()`, `dict()`, `tuple()`, `set()`.

```python
x = 10
x = "hello"
x = [1, 2, 3]
```

Related notes: [006-errors-and-exceptions](./006-errors-and-exceptions.md)

### None

- Represents absence of value; singleton.
- Default return of functions without explicit return.
- Check with `x is None` (not `x == None`).

```python
result = None
if result is None:
    print("No result")
```

Related notes: [003-functions](./003-functions.md)

### Type Hints

- Optional annotations; does not enforce at runtime (use `mypy` for checking).
- `variable: type` or `def f(x: int) -> str:`.
- From `typing`: `List[int]`, `Dict[str, int]`, `Optional[str]`.
- Python 3.9+: use `list[int]`, `dict[str, int]` directly (no import needed).

```python
def greet(name: str) -> str:
    return f"Hello, {name}"

from typing import List, Optional
def process(items: List[int], default: Optional[int] = None) -> int:
    ...
```

Related notes: [003-functions](./003-functions.md), [008-classes-and-oop](./008-classes-and-oop.md)

---

# Troubleshooting Flow (Quick)

```text
Problem: unexpected type behavior
    |
    v
[1] What type is it?
    type(x), isinstance(x, expected_type)
    |
    +-- wrong type --> check assignment, did you reassign the name?
    |
    v
[2] Is it a reference issue?
    x = some_list; y = x; y.append(...)
    |
    +-- yes --> use .copy() or copy.deepcopy() for nested structures
    |
    v
[3] Is it a mutability issue?
    trying to modify str/tuple/bytes?
    |
    +-- yes --> these are immutable; create a new object instead
    |
    v
[4] Is it a None issue?
    function returned None unexpectedly?
    |
    +-- yes --> check if function has explicit return statement
    |
    v
[5] Type conversion error?
    int("abc") --> ValueError
    |
    +-- yes --> validate input before converting; use try/except
```

# Quick Facts (Revision)

- Variables are names (references) to objects on the heap -- assignment does not copy.
- `x = y` makes both names point to the same object; mutating it via one name affects the other.
- Python has arbitrary-precision integers (no overflow) and IEEE 754 floats (precision limits).
- `bool` is a subclass of `int`: `True == 1`, `False == 0`.
- Falsy values: `False`, `None`, `0`, `0.0`, `""`, `[]`, `{}`, `()`, `set()`.
- Strings are immutable; every string method returns a new string.
- `is` checks identity (same object); `==` checks equality (same value). Use `is` for `None`.
- Type hints are optional and not enforced at runtime; use `mypy` for static checking.
