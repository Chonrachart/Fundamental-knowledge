list
dict
tuple
set
slice
comprehension

---

# list

- Ordered, mutable sequence.
- `[]` or `list()`.
- Index: `lst[0]`, `lst[-1]` (last), `lst[-2]` (second to last).
- Methods: `append`, `extend`, `insert`, `remove`, `pop`, `sort`, `reverse`, `index`, `count`.

```python
lst = [1, 2, 3]
lst.append(4)       # [1, 2, 3, 4]
lst.extend([5, 6])  # [1, 2, 3, 4, 5, 6]
lst.insert(0, 0)   # insert at index
lst.pop()          # remove and return last
lst.remove(2)      # remove first occurrence of value
lst.sort()         # in-place sort
```

### List Operations

- `+` concatenates; `*` repeats: `[1, 2] * 3` → `[1, 2, 1, 2, 1, 2]`
- `in` / `not in` — membership test.

# dict

- Key-value mapping; keys must be hashable (immutable: str, int, tuple).
- `{}` or `dict()`.
- Access: `d[key]` (KeyError if missing) or `d.get(key, default)`.
- `d.setdefault(key, default)` — get or set and return.

```python
d = {"a": 1, "b": 2}
d["a"]           # 1
d.get("c", 0)    # 0 (no KeyError)
d["c"] = 3       # add/update
del d["a"]       # remove
d.keys()         # view of keys
d.values()       # view of values
d.items()        # view of (k, v) pairs
```

# tuple

- Ordered, immutable sequence.
- `()` or `a, b` (tuple packing); single element: `(1,)`.
- Use for fixed data, return multiple values, dict keys.

```python
t = (1, 2, 3)
a, b = 1, 2      # unpacking
a, *rest = [1, 2, 3]  # rest = [2, 3]
```

# set

- Unordered, unique elements; no duplicates; no index.
- `{}` with no colons or `set()`; `{}` alone is empty dict.
- Methods: `add`, `remove`, `discard`, `union`, `intersection`, `difference`.

```python
s = {1, 2, 3}
s.add(4)
s.discard(2)     # no error if missing
s1 | s2          # union
s1 & s2          # intersection
s1 - s2          # difference
```

# slice

- `lst[start:stop:step]` — sublist; stop exclusive.
- Omit: `lst[:]` shallow copy, `lst[::2]` every other, `lst[::-1]` reverse.
- Negative indices count from end.

```python
lst = [0, 1, 2, 3, 4]
lst[1:4]    # [1, 2, 3]
lst[::2]    # [0, 2, 4]
lst[::-1]   # [4, 3, 2, 1, 0]
```

# Comprehension

- Build list/dict/set in one expression.
- Can include `if` filter; nested loops possible.

```python
squares = [x**2 for x in range(5)]           # [0, 1, 4, 9, 16]
evens = [x for x in lst if x % 2 == 0]
d = {k: v*2 for k, v in d.items()}
s = {x for x in lst if x > 0}
# Nested
[(i, j) for i in range(2) for j in range(2)]  # [(0,0),(0,1),(1,0),(1,1)]
```
