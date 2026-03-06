variable
assignment
type
dynamic typing
None
type hint

---

# Variable

- Name that refers to an object; no declaration.
- Create by assignment: `x = 10`.
- Names are case-sensitive: `name` and `Name` are different.

# Assignment

- `name = value` — binds name to object.
- Multiple: `a, b = 1, 2` (tuple unpacking) or `a = b = 0` (same object).
- Swap: `a, b = b, a`.

```python
a, b = 1, 2
a, b = b, a  # swap
x = y = []   # both refer to same list
```

# Type

- Built-in types: `int`, `float`, `str`, `bool`, `list`, `dict`, `tuple`, `set`, `bytes`.
- Check: `type(x)` or `isinstance(x, int)`.
- Convert: `int()`, `str()`, `float()`, `list()`, `dict()`, `tuple()`, `set()`.

---

# int

- Integer; arbitrary precision (no overflow).
- Literals: `42`, `0xff`, `0o10`, `0b1010`.
- Operators: `+`, `-`, `*`, `//` (floor div), `%`, `**`.
- `int("100")` — parse string; `int("ff", 16)` — parse with base (2–36).

```python
10 // 3    # 3
10 % 3     # 1
2 ** 10    # 1024
```

# float

- Floating-point; IEEE 754 double precision.
- Literals: `3.14`, `1e6`, `2.5e-3`.
- Precision limits; use `decimal.Decimal` for exact decimal.
- `float("3.14")` — parse string.
- `math.isclose(a, b)` for approximate equality.

```python
0.1 + 0.2  # 0.30000000000000004 (precision)
```

# bool

- Boolean; `True` or `False`.
- Subclass of `int`: `True == 1`, `False == 0`.
- Falsy: `False`, `None`, `0`, `0.0`, `""`, `[]`, `{}`, `()`, `set()`.
- `bool(x)` — truth value of x.

# str

- Immutable sequence of Unicode characters.
- Literals: `'...'`, `"..."`, `'''...'''`, `"""..."""`.
- Raw: `r'\n'` — backslash literal (no escape).
- f-string: `f"x={x}"` — interpolate; `f"{x:.2f}"` — format.

### str Methods

- `s.upper()`, `s.lower()`, `s.strip()`, `s.split()`, `s.join()`
- `s.startswith()`, `s.endswith()`, `s.replace()`, `s.find()`, `s.index()`
- `s.format()`, `s.encode()` — to bytes

```python
"  hello  ".strip()       # "hello"
"a,b,c".split(",")       # ["a", "b", "c"]
",".join(["a", "b"])     # "a,b"
"hello".replace("l", "x") # "hexxo"
```

# list

- Ordered, mutable sequence.
- Literal: `[1, 2, 3]`.
- Index: `lst[0]`, `lst[-1]`; slice: `lst[1:3]`.
- Methods: `append`, `extend`, `insert`, `remove`, `pop`, `sort`, `reverse`, `index`, `count`.
- `len(lst)`, `x in lst`.

# dict

- Key-value mapping; keys must be hashable (immutable).
- Literal: `{"a": 1, "b": 2}`.
- Access: `d[key]`, `d.get(key, default)`.
- Methods: `keys()`, `values()`, `items()`, `setdefault()`, `pop()`.
- `len(d)`, `key in d`.

# tuple

- Ordered, immutable sequence.
- Literal: `(1, 2, 3)` or `1, 2, 3`; single: `(1,)`.
- Use for fixed data, return multiple values, dict keys.
- Methods: `index`, `count`; no mutating methods.

# set

- Unordered, unique elements; no duplicates; no index.
- Literal: `{1, 2, 3}`; empty: `set()` (not `{}`).
- Methods: `add`, `remove`, `discard`, `union`, `intersection`, `difference`.
- Operators: `|`, `&`, `-`, `^` (symmetric diff).
- Hashable elements only.

# bytes

- Immutable sequence of bytes (0–255).
- Literal: `b'hello'`, `bytes([65, 66, 67])`.
- `str.encode()` → bytes; `bytes.decode()` → str.
- Use for binary data, file I/O in binary mode.

```python
"hello".encode()      # b'hello'
b'hello'.decode()    # "hello"
```

# Type Summary

| Type   | Mutable | Ordered   | Duplicates | Literal / Create |
| :----- | :------ | :-------- | :--------- | :--------------- |
| int    | —       | —         | —          | `42`             |
| float  | —       | —         | —          | `3.14`            |
| bool   | —       | —         | —          | `True`, `False`   |
| str    | No      | Yes       | Yes        | `"..."`           |
| list   | Yes     | Yes       | Yes        | `[1, 2, 3]`       |
| dict   | Yes     | Yes (3.7+)| No keys    | `{"a": 1}`        |
| tuple  | No      | Yes       | Yes        | `(1, 2, 3)`       |
| set    | Yes     | No        | No         | `{1, 2, 3}`       |
| bytes  | No      | Yes       | Yes        | `b"..."`          |

# Dynamic Typing

- Variable can refer to different types over time.
- Type is determined at runtime, not declaration.
- Use `isinstance()` for type checks in code.

```python
x = 10
x = "hello"
x = [1, 2, 3]
```

# None

- Represents absence of value; singleton.
- Default return of functions without explicit return.
- Check with `x is None` (not `x == None`).

```python
result = None
if result is None:
    print("No result")
```

# Type Hint

- Optional annotations; does not enforce at runtime (use `mypy` for checking).
- `variable: type` or `def f(x: int) -> str:`.
- From `typing`: `List[int]`, `Dict[str, int]`, `Optional[str]`.

```python
def greet(name: str) -> str:
    return f"Hello, {name}"

from typing import List, Optional
def process(items: List[int], default: Optional[int] = None) -> int:
    ...
```
