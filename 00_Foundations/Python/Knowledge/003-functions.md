def
return
arguments
args
kwargs
lambda
scope

---

# def

- Define function with `def name():` or `def name(params):`.
- Function is an object; can be assigned, passed, returned.

```python
def greet():
    print("Hello")

def add(a, b):
    return a + b

# Function as value
f = add
f(1, 2)  # 3
```

# return

- Return value; exits function immediately.
- Without value returns `None`.
- Can return multiple values (as tuple): `return a, b`.

```python
def get_value():
    return 42

def get_pair():
    return 1, 2  # tuple
a, b = get_pair()
```

# Arguments

- Positional: `f(a, b)` — order matters.
- Default: `def f(a, b=0):` — default only for missing args.
- Keyword: `f(a=1, b=2)` — by name; order doesn't matter.
- Defaults evaluated once at definition; avoid mutable defaults (`def f(x=[])` is wrong).

```python
def greet(name, greeting="Hello"):
    return f"{greeting}, {name}"

greet("Bob")                    # "Hello, Bob"
greet("Bob", "Hi")              # "Hi, Bob"
greet(greeting="Hi", name="Bob") # keyword order
```

### Argument Order

- Positional-only, then `*args`, then keyword-only (after `*`).

```python
def f(a, b, *args, c, d=0):
    pass  # a, b positional; args tuple; c, d keyword-only
```

# *args and **kwargs

- `*args` — extra positional args as tuple.
- `**kwargs` — extra keyword args as dict.
- Naming is convention; `*` and `**` matter.

```python
def f(*args, **kwargs):
    print(args, kwargs)

f(1, 2, x=3)       # (1, 2) {'x': 3}
f(*[1, 2], **{"x": 3})  # unpack into call
```

# lambda

- Anonymous function; single expression only.
- Syntax: `lambda args: expression`
- No `return` keyword; expression result is returned.
- Use for short, one-off functions; prefer `def` for anything complex.

### Basic Examples

```python
square = lambda x: x ** 2
square(5)   # 25

add = lambda a, b: a + b
add(3, 4)   # 7
```

### With map, filter

```python
nums = [1, 2, 3, 4, 5]
list(map(lambda x: x * 2, nums))           # [2, 4, 6, 8, 10]
list(filter(lambda x: x % 2 == 0, nums))  # [2, 4]
```

### With sorted (key function)

```python
pairs = [("b", 2), ("a", 1), ("c", 3)]
sorted(pairs, key=lambda p: p[0])   # by first element
sorted(pairs, key=lambda p: p[1])   # by second element

users = [{"name": "Bob", "age": 30}, {"name": "Alice", "age": 25}]
sorted(users, key=lambda u: u["age"])
```

### Multiple Arguments

```python
multiply = lambda x, y: x * y
multiply(3, 4)   # 12
```

### Limitations

- Only one expression; no statements (`if` as expression is OK: `lambda x: x if x > 0 else 0`).
- No `return`, `pass`, loops, or multiple lines.
- For complex logic, use `def` instead.

# Scope

- **Local**: inside function; created on assignment.
- **Global**: module level; use `global name` to assign (not just read).
- **Enclosing**: `nonlocal name` for nested functions (modify outer, not global).

```python
x = 1  # global

def f():
    x = 2   # local; shadows global
    print(x) # 2

def g():
    global x
    x = 3   # modifies global

def outer():
    n = 0
    def inner():
        nonlocal n
        n += 1  # modifies outer's n
    return inner
```
