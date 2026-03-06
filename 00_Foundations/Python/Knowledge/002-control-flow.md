if
elif
else
for
while
match
range
break
continue

---

# if, elif, else

- Condition does not need parentheses; colon and indentation define block.
- Falsy: `False`, `None`, `0`, `""`, `[]`, `{}`, `()`.
- Truthy: everything else.

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

# for

- Iterate over iterable: list, range, string, dict keys/values/items, file lines.
- `enumerate(iterable)` — index and value.
- `zip(a, b)` — pair elements from two iterables.

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

# while

- Loop while condition is true.
- Use `break` to exit; `continue` to skip to next iteration.

```python
while count > 0:
    count -= 1

# Infinite with break
while True:
    line = input()
    if line == "quit":
        break
```

# match (Python 3.10+)

- Pattern matching; alternative to long if-elif chains.
- `_` is wildcard (match anything).

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

# range

- `range(stop)` — 0 to stop-1.
- `range(start, stop)` — start to stop-1.
- `range(start, stop, step)` — with step; negative step for countdown.

```python
list(range(5))        # [0, 1, 2, 3, 4]
list(range(2, 6))     # [2, 3, 4, 5]
list(range(0, 10, 2)) # [0, 2, 4, 6, 8]
list(range(5, 0, -1)) # [5, 4, 3, 2, 1]
```

# break and continue

- `break` — exit innermost loop immediately.
- `continue` — skip rest of iteration, go to next.

```python
for i in range(10):
    if i == 5:
        break
    if i % 2 == 0:
        continue
    print(i)  # 1, 3
```

# else on Loops

- `else` on `for`/`while` runs if loop completes without `break`.

```python
for i in range(5):
    if i == 10:
        break
else:
    print("loop completed normally")
```
