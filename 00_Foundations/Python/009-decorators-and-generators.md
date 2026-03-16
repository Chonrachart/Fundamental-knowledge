# Decorators and Generators

- Decorators wrap functions or classes to add behavior without modifying source code -- they are functions that take a function and return a function.
- Generators produce values lazily with `yield`, pausing and resuming execution -- they follow the iterator protocol and use almost no memory for large sequences.
- Together with itertools and context managers, they form Python's toolkit for composable, memory-efficient, and clean control flow.

# Architecture

```text
Decorator wrapping:

+-------------------+      +-------------------+      +-------------------+
|  original func    | ---> |    decorator()     | ---> |   wrapper func    |
|  def greet():     |      |  receives greet    |      |  adds behavior    |
|    return "hi"    |      |  returns wrapper   |      |  calls greet()    |
+-------------------+      +-------------------+      +-------------------+

@decorator         <==>    greet = decorator(greet)


Stacked decorators (applied bottom-up):

@decorator_a                       greet = decorator_a(decorator_b(greet))
@decorator_b
def greet(): ...


Generator state machine:

+----------+    call gen()    +-----------+    next()    +-----------+
| created  | --------------> | suspended | -----------> |  running  |
|          |                 |           | <----------- |           |
+----------+                 +-----------+    yield     +-----------+
                                   |                         |
                                   |     StopIteration       |
                                   +---- (return) -------> +----------+
                                                           | completed|
                                                           +----------+


Iterator protocol:

+------------------+
|   iterable       |    has __iter__() --> returns iterator
+------------------+
        |
        v
+------------------+
|   iterator       |    has __iter__() + __next__()
+------------------+    raises StopIteration when exhausted
        |
        v
   for x in obj:   <-- Python calls iter(), then next() repeatedly
```

# Mental Model

```text
Decorator wrapping flow:

  [1] Python reads @log_calls          --> finds the decorator function
  [2] Python reads def add(a, b):      --> creates the original function
  [3] Python executes add = log_calls(add)  --> replaces add with wrapper
  [4] Caller runs add(2, 3)            --> actually calls wrapper(2, 3)
  [5] wrapper logs, calls original add, logs result, returns it


Generator yield/send cycle:

  [1] gen = counter(3)       --> creates generator object (no code runs yet)
  [2] next(gen)              --> runs until first yield, returns value, suspends
  [3] next(gen)              --> resumes from yield, runs until next yield
  [4] next(gen)              --> last yield
  [5] next(gen)              --> function returns, raises StopIteration
```

```python
# Decorator example -- log function calls
import functools

def log_calls(func):
    @functools.wraps(func)        # preserves func.__name__, __doc__
    def wrapper(*args, **kwargs):
        print(f"calling {func.__name__}({args}, {kwargs})")
        result = func(*args, **kwargs)
        print(f"  returned {result}")
        return result
    return wrapper

@log_calls
def add(a, b):
    return a + b

add(2, 3)
# calling add((2, 3), {})
#   returned 5
```

```python
# Generator example -- lazy sequence
def countdown(n):
    while n > 0:
        yield n       # suspend here, return n
        n -= 1        # resume here on next()

for val in countdown(3):
    print(val)        # 3, 2, 1
```

# Core Building Blocks

### Function Decorators

- A decorator is any callable that takes a function and returns a callable.
- `@decorator` syntax is syntactic sugar for `func = decorator(func)`.
- Always use `@functools.wraps(func)` in wrapper to preserve original metadata.
- Decorators can add logging, timing, caching, access control, retry logic.

```python
import functools
import time

def timer(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = func(*args, **kwargs)
        elapsed = time.perf_counter() - start
        print(f"{func.__name__} took {elapsed:.4f}s")
        return result
    return wrapper
```

Related notes: [003-functions](./003-functions.md), [008-classes-and-oop](./008-classes-and-oop.md)

### Parameterized Decorators

- A decorator that accepts arguments needs an extra layer of nesting.
- Outer function takes the parameter, returns the actual decorator.
- Pattern: `decorator_factory(args) -> decorator(func) -> wrapper(*args)`.

```python
def repeat(n):
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            for _ in range(n):
                result = func(*args, **kwargs)
            return result
        return wrapper
    return decorator

@repeat(3)          # repeat is called first, returns decorator
def say(msg):
    print(msg)

say("hello")        # prints "hello" three times
```

Related notes: [003-functions](./003-functions.md)

### Common Built-in Decorators

- `@property` -- turn method into a managed attribute (see [008-classes-and-oop](./008-classes-and-oop.md)).
- `@classmethod` -- method receives `cls` instead of `self`.
- `@staticmethod` -- plain function namespaced in the class.
- `@functools.lru_cache(maxsize=128)` -- memoize function results (LRU eviction).
- `@functools.wraps` -- preserve wrapped function metadata.
- `@dataclasses.dataclass` -- auto-generate class boilerplate.
- `@abc.abstractmethod` -- enforce method implementation in subclasses.

```python
from functools import lru_cache

@lru_cache(maxsize=None)
def fib(n):
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)

fib(100)            # instant -- cached
fib.cache_info()    # CacheInfo(hits=98, misses=101, ...)
```

Related notes: [008-classes-and-oop](./008-classes-and-oop.md), [007-modules-and-imports](./007-modules-and-imports.md)

### Generator Functions

- A function containing `yield` becomes a generator function.
- Calling it returns a generator object -- no code runs until `next()`.
- `yield` suspends execution and produces a value; `next()` resumes.
- `return` (or falling off end) raises `StopIteration`.
- Generators are one-shot -- once exhausted, they cannot be restarted.
- `yield from iterable` delegates to a sub-generator or iterable.

```python
def read_chunks(filepath, chunk_size=1024):
    with open(filepath, "rb") as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            yield chunk       # process large file without loading it all

# Generator expression (like list comprehension but lazy)
squares = (x**2 for x in range(1_000_000))   # no memory spike
```

Related notes: [005-io-and-files](./005-io-and-files.md), [002-control-flow](./002-control-flow.md)

### Iterator Protocol

- An **iterable** has `__iter__()` that returns an iterator.
- An **iterator** has `__iter__()` (returns self) and `__next__()` (returns next value or raises `StopIteration`).
- `for` loops call `iter()` then `next()` repeatedly under the hood.
- Generators implement the iterator protocol automatically.

```python
class Range:
    def __init__(self, start, end):
        self.current = start
        self.end = end

    def __iter__(self):
        return self

    def __next__(self):
        if self.current >= self.end:
            raise StopIteration
        val = self.current
        self.current += 1
        return val

for n in Range(1, 4):
    print(n)              # 1, 2, 3
```

Related notes: [008-classes-and-oop](./008-classes-and-oop.md), [002-control-flow](./002-control-flow.md)

### itertools

- Standard library module for efficient iterator building blocks.
- All functions return iterators (lazy evaluation).

```python
import itertools

# chain -- flatten multiple iterables into one
list(itertools.chain([1, 2], [3, 4]))        # [1, 2, 3, 4]

# islice -- slice an iterator (no negative indices)
list(itertools.islice(range(100), 5, 10))    # [5, 6, 7, 8, 9]

# groupby -- group consecutive elements by key (must be sorted first)
data = sorted(["apple", "avocado", "banana", "blueberry"], key=lambda x: x[0])
for key, group in itertools.groupby(data, key=lambda x: x[0]):
    print(key, list(group))
# a ['apple', 'avocado']
# b ['banana', 'blueberry']

# product -- cartesian product
list(itertools.product("AB", "12"))          # [('A','1'),('A','2'),('B','1'),('B','2')]

# combinations / permutations
list(itertools.combinations("ABC", 2))       # [('A','B'),('A','C'),('B','C')]
```

Related notes: [007-modules-and-imports](./007-modules-and-imports.md), [004-data-structures](./004-data-structures.md)

### Context Managers

- `with` statement ensures setup/teardown code always runs (even on exceptions).
- Class-based: define `__enter__` (setup, return resource) and `__exit__` (teardown).
- Function-based: use `@contextlib.contextmanager` with a single `yield`.
- `__exit__` receives exception info; returning `True` suppresses the exception.

```python
from contextlib import contextmanager

@contextmanager
def temp_directory():
    import tempfile, shutil
    path = tempfile.mkdtemp()
    try:
        yield path             # resource given to `as` variable
    finally:
        shutil.rmtree(path)    # cleanup always runs

with temp_directory() as tmpdir:
    print(tmpdir)              # /tmp/xyz...
# directory is deleted after the block
```

```python
# Class-based context manager
class Timer:
    def __enter__(self):
        import time
        self.start = time.perf_counter()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        import time
        self.elapsed = time.perf_counter() - self.start
        print(f"Elapsed: {self.elapsed:.4f}s")
        return False           # do not suppress exceptions

with Timer() as t:
    sum(range(1_000_000))
```

Related notes: [006-errors-and-exceptions](./006-errors-and-exceptions.md), [005-io-and-files](./005-io-and-files.md)

---

# Troubleshooting Flow (Quick)

```text
Problem: decorator or generator not behaving as expected
    |
    v
[1] Decorated function lost its name/docstring?
    print(func.__name__)
    |
    +-- shows "wrapper" --> add @functools.wraps(func) inside decorator
    |
    v
[2] Generator runs no code when called?
    type(result)
    |
    +-- <generator object> --> generators are lazy, use next() or for loop
    +-- you wanted a list --> wrap in list() or use list comprehension
    |
    v
[3] Generator raises StopIteration unexpectedly?
    |
    +-- generator exhausted --> generators are one-shot, recreate if needed
    +-- bare next() call --> use next(gen, default) for safe access
    |
    v
[4] Decorator breaks when stacking multiple decorators?
    |
    +-- order matters --> bottom decorator applied first, top applied last
    +-- check each layer preserves *args, **kwargs and return value
    |
    v
[5] Context manager not cleaning up?
    |
    +-- using @contextmanager --> ensure yield is inside try/finally
    +-- class-based --> check __exit__ is defined and handles exceptions
```

# Quick Facts (Revision)

- `@decorator` is sugar for `func = decorator(func)` -- the decorator receives and returns a callable.
- Always use `@functools.wraps(func)` to preserve `__name__`, `__doc__`, `__module__` of the wrapped function.
- Stacked decorators apply bottom-up: `@a @b def f` means `f = a(b(f))`.
- A generator function contains `yield`; calling it returns a generator object without running any code.
- Generators implement the iterator protocol (`__iter__`, `__next__`) automatically.
- `yield from sub_gen` delegates to a sub-generator, forwarding `next()` and `send()` calls.
- `itertools` functions return lazy iterators -- they consume almost no memory regardless of input size.
- `@contextmanager` requires exactly one `yield`; put it inside `try/finally` for guaranteed cleanup.
