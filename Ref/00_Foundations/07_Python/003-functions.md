# Functions

- Functions are reusable blocks of code defined with `def`, called by name, and returning a value (or `None`).
- Arguments are resolved by position first, then keyword; `*args` and `**kwargs` capture extras.
- Python uses the LEGB rule (Local, Enclosing, Global, Built-in) to resolve variable names at runtime.

# Architecture

```text
+------------------------------------------------------+
|  Built-in Scope (len, print, range, ...)             |
|  +--------------------------------------------------+|
|  |  Global Scope (module level)                     ||
|  |  +----------------------------------------------+||
|  |  |  Enclosing Scope (outer function)            |||
|  |  |  +------------------------------------------+|||
|  |  |  |  Local Scope (current function)          ||||
|  |  |  |                                          ||||
|  |  |  |  x = 10        <-- local assignment      ||||
|  |  |  |  print(y)      <-- looks up LEGB chain   ||||
|  |  |  +------------------------------------------+|||
|  |  +----------------------------------------------+||
|  +--------------------------------------------------+|
+------------------------------------------------------+

Call stack (LIFO):
                          +------------------+
                          |  inner()         |  <-- top of stack (executing)
                          +------------------+
                          |  outer()         |
                          +------------------+
                          |  <module>        |  <-- entry point
                          +------------------+
```

# Mental Model

```text
Argument resolution order when calling f(1, 2, x=3):

  [1] Match positional args left to right
  [2] Match keyword args by name
  [3] Remaining positionals go to *args (tuple)
  [4] Remaining keywords go to **kwargs (dict)
  [5] Apply defaults for any unmatched parameters
  [6] Raise TypeError if required params still missing
```

```python
def show(a, b, *args, key="default", **kwargs):
    print(a, b, args, key, kwargs)

show(1, 2, 3, 4, key="K", extra=99)
# 1 2 (3, 4) K {'extra': 99}
#  |  |   |       |       |
#  |  |   |       |       +-- **kwargs captures extra=99
#  |  |   |       +-- keyword arg matched by name
#  |  |   +-- *args captures leftover positionals
#  |  +-- positional b
#  +-- positional a
```

# Core Building Blocks

### Defining Functions

- Define with `def name():` or `def name(params):`.
- Function is an object; can be assigned, passed, returned.
- `return` exits the function and sends a value back; without a value returns `None`.
- Can return multiple values as a tuple: `return a, b`.

```python
def greet():
    print("Hello")

def add(a, b):
    return a + b

# Function as value
f = add
f(1, 2)  # 3

def get_pair():
    return 1, 2  # tuple
a, b = get_pair()
```

Related notes: [002-control-flow](./002-control-flow.md), [009-decorators-and-generators](./009-decorators-and-generators.md)
- Functions return `None` by default if no `return` statement is reached.
- `return a, b` returns a tuple; unpack with `x, y = f()`.
- Functions are first-class objects: assign to variables, pass as arguments, return from other functions.

### Arguments and Parameters

- Positional: `f(a, b)` -- order matters.
- Default: `def f(a, b=0):` -- default only for missing args.
- Keyword: `f(a=1, b=2)` -- by name; order does not matter.
- Defaults evaluated once at definition; avoid mutable defaults (`def f(x=[])` is a bug).
- Positional-only, then `*args`, then keyword-only (after `*`).

```python
def greet(name, greeting="Hello"):
    return f"{greeting}, {name}"

greet("Bob")                     # "Hello, Bob"
greet("Bob", "Hi")               # "Hi, Bob"
greet(greeting="Hi", name="Bob") # keyword order

# Argument order in signature
def f(a, b, *args, c, d=0):
    pass  # a, b positional; args tuple; c, d keyword-only
```

Related notes: [001-variables-and-types](./001-variables-and-types.md)
- Mutable default arguments are evaluated once -- use `None` sentinel instead.

### *args and **kwargs

- `*args` -- extra positional args collected as a tuple.
- `**kwargs` -- extra keyword args collected as a dict.
- Naming is convention; `*` and `**` are what matter.
- `*list` and `**dict` unpack when calling a function.

```python
def f(*args, **kwargs):
    print(args, kwargs)

f(1, 2, x=3)              # (1, 2) {'x': 3}
f(*[1, 2], **{"x": 3})    # unpack into call
```

Related notes: [004-data-structures](./004-data-structures.md)
- Argument order in signature: positional, `*args`, keyword-only, `**kwargs`.

### Lambda

- Anonymous function; single expression only.
- Syntax: `lambda args: expression`.
- No `return` keyword; expression result is returned automatically.
- Use for short, one-off functions; prefer `def` for anything complex.

```python
# Basic
square = lambda x: x ** 2
square(5)   # 25

add = lambda a, b: a + b
add(3, 4)   # 7

# Multiple arguments
multiply = lambda x, y: x * y
multiply(3, 4)   # 12
```

```python
# With map, filter
nums = [1, 2, 3, 4, 5]
list(map(lambda x: x * 2, nums))           # [2, 4, 6, 8, 10]
list(filter(lambda x: x % 2 == 0, nums))   # [2, 4]
```

```python
# With sorted (key function)
pairs = [("b", 2), ("a", 1), ("c", 3)]
sorted(pairs, key=lambda p: p[0])   # by first element
sorted(pairs, key=lambda p: p[1])   # by second element

users = [{"name": "Bob", "age": 30}, {"name": "Alice", "age": 25}]
sorted(users, key=lambda u: u["age"])
```

- Limitations:
  - Only one expression; no statements (`if` as expression is OK: `lambda x: x if x > 0 else 0`).
  - No `return`, `pass`, loops, or multiple lines.
  - For complex logic, use `def` instead.

Related notes: [009-decorators-and-generators](./009-decorators-and-generators.md)
- `def` creates a function object; `lambda` creates an anonymous single-expression function.

### Scope (LEGB Rule)
- **Local**: inside function; created on assignment.
- **Enclosing**: outer function scope in nested functions; use `nonlocal` to modify.
- **Global**: module level; use `global name` to assign (not just read).
- **Built-in**: names pre-defined by Python (`len`, `print`, `range`, etc.).
- LEGB: Local -> Enclosing -> Global -> Built-in; Python searches in this order.
- `global` and `nonlocal` keywords let you write to outer scopes; without them, assignment creates a local.
