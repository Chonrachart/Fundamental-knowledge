# Control Flow

- Control flow determines the order in which statements execute: branching (if), looping (for/while), and pattern matching (match).
- Python uses indentation (not braces) to define blocks; conditions do not need parentheses.
- Truthiness drives all branching -- every object evaluates to True or False in a boolean context.

# Architecture

```text
Control Flow Decision Paths

                         +------------------+
                         |   statement      |
                         +------------------+
                                 |
              +------------------+------------------+
              |                  |                  |
              v                  v                  v
       +-----------+      +-----------+      +-----------+
       | branching |      | looping   |      | matching  |
       +-----------+      +-----------+      +-----------+
              |                  |                  |
              v                  v                  v
        if / elif / else   for / while         match / case
              |                  |              (3.10+)
              v                  v
        execute one        repeat block
        matching block     until done
                                 |
                          +------+------+
                          |             |
                          v             v
                       break       continue
                    (exit loop)  (next iteration)
```

# Mental Model

```text
How Python evaluates truthiness:

  [1] bool(x) is called on any object used in a condition
  [2] Falsy values:  False, None, 0, 0.0, "", [], {}, (), set()
  [3] Everything else is Truthy

  if my_list:        -->  bool([1,2,3]) --> True  --> block runs
  if []:             -->  bool([])      --> False --> block skipped
  if "":             -->  bool("")      --> False --> block skipped
  if "hello":        -->  bool("hello") --> True  --> block runs
```

```python
# concrete example -- truthiness in action
data = []

if data:
    print("has items")     # skipped -- empty list is falsy
else:
    print("empty")         # prints "empty"

data.append(42)

if data:
    print("has items")     # prints "has items" -- non-empty list is truthy
```

# Core Building Blocks

### Conditionals (if / elif / else)

- Condition does not need parentheses; colon and indentation define block.
- `elif` chains additional conditions; `else` is the fallback.
- Chained comparison: `0 < x < 10` (no need for `and`).

```python
if x > 0:
    print("positive")
elif x < 0:
    print("negative")
else:
    print("zero")

# Chained comparison
if 0 < x < 10:
    print("between 0 and 10")
```

Related notes: [001-variables-and-types](./001-variables-and-types.md)

### Iteration (for)

- Iterate over any iterable: list, range, string, dict keys/values/items, file lines.
- `enumerate(iterable)` -- index and value together.
- `zip(a, b)` -- pair elements from two iterables.

```python
for i in range(5):
    print(i)

for i, item in enumerate(["a", "b", "c"]):
    print(i, item)  # 0 a, 1 b, 2 c

for k, v in {"a": 1, "b": 2}.items():
    print(k, v)

for a, b in zip([1, 2], ["x", "y"]):
    print(a, b)  # 1 x, 2 y
```

Related notes: [004-data-structures](./004-data-structures.md), [009-decorators-and-generators](./009-decorators-and-generators.md)

### While Loops

- Loop while condition is true.
- Use `break` to exit; `continue` to skip to next iteration.
- Common pattern: `while True:` with `break` for input loops.

```python
while count > 0:
    count -= 1

# Infinite with break
while True:
    line = input()
    if line == "quit":
        break
```

Related notes: [006-errors-and-exceptions](./006-errors-and-exceptions.md)

### Pattern Matching (match) -- Python 3.10+

- Structural pattern matching; alternative to long if-elif chains.
- `_` is wildcard (match anything).
- Supports literal matching, unpacking, guard clauses, and class patterns.

```python
match status:
    case 200:
        print("OK")
    case 404:
        print("Not found")
    case 400 | 422:
        print("Bad request")
    case _:
        print("Other")

# Match with unpacking
match point:
    case (0, 0):
        print("origin")
    case (x, 0):
        print(f"x-axis at {x}")
```

Related notes: [001-variables-and-types](./001-variables-and-types.md)

### Range

- `range(stop)` -- 0 to stop-1.
- `range(start, stop)` -- start to stop-1.
- `range(start, stop, step)` -- with step; negative step for countdown.
- Returns a lazy range object, not a list; memory efficient.

```python
list(range(5))        # [0, 1, 2, 3, 4]
list(range(2, 6))     # [2, 3, 4, 5]
list(range(0, 10, 2)) # [0, 2, 4, 6, 8]
list(range(5, 0, -1)) # [5, 4, 3, 2, 1]
```

Related notes: [003-functions](./003-functions.md)

### Loop Control (break, continue, else)

- `break` -- exit innermost loop immediately.
- `continue` -- skip rest of current iteration, go to next.
- `else` on `for`/`while` -- runs only if loop completes without `break`.

```python
for i in range(10):
    if i == 5:
        break
    if i % 2 == 0:
        continue
    print(i)  # 1, 3

# else on loop -- runs when no break occurred
for i in range(5):
    if i == 10:
        break
else:
    print("loop completed normally")
```

Related notes: [006-errors-and-exceptions](./006-errors-and-exceptions.md)

---

# Troubleshooting Flow (Quick)

```text
Problem: control flow not behaving as expected
    |
    v
[1] Is the condition evaluating correctly?
    print(bool(value)), print(type(value))
    |
    +-- unexpected falsy/truthy --> check truthiness rules (0, "", [], None are falsy)
    |
    v
[2] Is the indentation correct?
    Python uses indentation to define blocks
    |
    +-- IndentationError --> fix spacing (use consistent tabs or spaces, not both)
    +-- wrong block runs --> check alignment of if/elif/else/for/while
    |
    v
[3] Is the loop iterating the right number of times?
    range(5) is 0-4, not 0-5
    |
    +-- off-by-one --> check range start/stop values
    +-- infinite loop --> ensure condition will eventually be False; add break
    |
    v
[4] Is break/continue affecting the wrong loop?
    break/continue only affect the innermost loop
    |
    +-- need to exit outer loop --> use a flag variable or refactor into a function with return
    |
    v
[5] Does the else on loop run unexpectedly?
    else runs when loop finishes WITHOUT break
    |
    +-- runs when it should not --> a break was never triggered; check break condition
```

# Quick Facts (Revision)

- Python uses indentation to define blocks; no braces, no end keywords.
- Falsy values: `False`, `None`, `0`, `0.0`, `""`, `[]`, `{}`, `()`, `set()`. Everything else is truthy.
- `for` iterates over any iterable; `enumerate()` adds an index, `zip()` pairs elements.
- `while True: ... break` is the standard pattern for input loops and polling.
- `match/case` (3.10+) does structural pattern matching, not just value comparison.
- `range()` is lazy (does not create a list in memory); use `list(range(...))` to materialize.
- `else` on a loop runs only when no `break` occurred -- useful for search patterns.
- `break` and `continue` affect only the innermost loop.
