# Data Structures

- Python provides four core collection types: list (ordered, mutable), dict (keyed, mutable), tuple (ordered, immutable), and set (unordered, unique).
- Choose by access pattern: index-based (list/tuple), key-based (dict), or membership-based (set).
- Comprehensions build any of these collections in a single, readable expression.

# Architecture

```text
                    +---------------------------+
                    |    Python Collections     |
                    +---------------------------+
                    |                           |
          Ordered / Sequenced           Unordered
          |                  |                |
    +-----+------+    +-----+-----+    +-----+-----+
    |  Mutable   |    | Immutable |    |  Mutable   |
    +------------+    +-----------+    +-----------+
    |   list     |    |   tuple   |    |   set     |
    | [1, 2, 3]  |    | (1, 2, 3) |    | {1, 2, 3} |
    | indexed    |    | indexed   |    | no index  |
    | duplicates |    | duplicates|    | unique    |
    +------------+    +-----------+    +-----------+

    +---------------------------+
    |  dict  (keyed, mutable)   |
    |  {"a": 1, "b": 2}        |
    |  insertion-ordered (3.7+) |
    |  keys: unique, hashable   |
    +---------------------------+

    Hashable (can be dict key / set member): str, int, float, bool, tuple
    Not hashable: list, dict, set
```

# Mental Model

```text
Choosing the right data structure:

  Need ordered sequence?
      |
      +-- yes --> Need to modify it?
      |               |
      |               +-- yes --> list
      |               +-- no  --> tuple
      |
      +-- no  --> Need key-value pairs?
                      |
                      +-- yes --> dict
                      +-- no  --> Need unique elements?
                                      |
                                      +-- yes --> set
                                      +-- no  --> list (default)
```

```python
# Concrete example: picking the right type
names = ["Alice", "Bob", "Alice"]  # list  -- ordered, allows duplicates
point = (10, 20)                   # tuple -- fixed pair, immutable
config = {"host": "db", "port": 5432}  # dict -- lookup by key
seen = {"Alice", "Bob"}            # set   -- fast membership, no dups
```

# Core Building Blocks

### Lists

- Ordered, mutable sequence. Create with `[]` or `list()`.
- Index: `lst[0]`, `lst[-1]` (last), `lst[-2]` (second to last).
- Methods: `append`, `extend`, `insert`, `remove`, `pop`, `sort`, `reverse`, `index`, `count`.

```python
lst = [1, 2, 3]
lst.append(4)       # [1, 2, 3, 4]
lst.extend([5, 6])  # [1, 2, 3, 4, 5, 6]
lst.insert(0, 0)    # insert at index
lst.pop()           # remove and return last
lst.remove(2)       # remove first occurrence of value
lst.sort()          # in-place sort
```

- `+` concatenates; `*` repeats: `[1, 2] * 3` -> `[1, 2, 1, 2, 1, 2]`.
- `in` / `not in` -- membership test.

Related notes: [003-functions](./003-functions.md), [005-io-and-files](./005-io-and-files.md)

### Dictionaries

- Key-value mapping; keys must be hashable (immutable: str, int, tuple).
- Create with `{}` or `dict()`.
- Access: `d[key]` (KeyError if missing) or `d.get(key, default)`.
- `d.setdefault(key, default)` -- get or set and return.

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

Related notes: [002-control-flow](./002-control-flow.md), [003-functions](./003-functions.md)

### Tuples

- Ordered, immutable sequence. Create with `()` or `a, b` (tuple packing).
- Single element tuple: `(1,)` -- trailing comma required.
- Use for fixed data, returning multiple values, dict keys, and unpacking.

```python
t = (1, 2, 3)
a, b = 1, 2          # unpacking
a, *rest = [1, 2, 3] # rest = [2, 3]
```

Related notes: [003-functions](./003-functions.md)

### Sets

- Unordered collection of unique elements; no duplicates, no index.
- Create with `{1, 2, 3}` or `set()`; note `{}` alone creates an empty dict.
- Methods: `add`, `remove` (raises KeyError), `discard` (no error), `union`, `intersection`, `difference`.

```python
s = {1, 2, 3}
s.add(4)
s.discard(2)     # no error if missing
s1 | s2          # union
s1 & s2          # intersection
s1 - s2          # difference
s1 ^ s2          # symmetric difference
```

Related notes: [001-variables-and-types](./001-variables-and-types.md)

### Slicing

- Syntax: `seq[start:stop:step]` -- stop is exclusive.
- Omit fields: `lst[:]` shallow copy, `lst[::2]` every other, `lst[::-1]` reverse.
- Negative indices count from end.
- Works on lists, tuples, and strings.

```python
lst = [0, 1, 2, 3, 4]
lst[1:4]    # [1, 2, 3]
lst[::2]    # [0, 2, 4]
lst[::-1]   # [4, 3, 2, 1, 0]
```

Related notes: [001-variables-and-types](./001-variables-and-types.md)

### Comprehensions

- Build list, dict, or set in one expression.
- Can include `if` filter; nested loops are read left to right.

```python
# List comprehension
squares = [x**2 for x in range(5)]           # [0, 1, 4, 9, 16]
evens = [x for x in lst if x % 2 == 0]

# Dict comprehension
d = {k: v*2 for k, v in d.items()}

# Set comprehension
s = {x for x in lst if x > 0}

# Nested
[(i, j) for i in range(2) for j in range(2)]  # [(0,0),(0,1),(1,0),(1,1)]
```

Related notes: [002-control-flow](./002-control-flow.md)

---

# Troubleshooting Guide

```text
Problem: unexpected data structure behavior
    |
    v
[1] TypeError: unhashable type?
    Tried to use list/dict/set as dict key or set member.
    |
    +-- fix --> convert to tuple (for lists) or frozenset (for sets)
    |
    v
[2] KeyError on dict access?
    |
    +-- fix --> use d.get(key, default) or check with `if key in d`
    |
    v
[3] IndexError: list index out of range?
    |
    +-- fix --> check len(lst) before access; use try/except
    |
    v
[4] Mutating a list while iterating?
    Items skipped or unexpected results.
    |
    +-- fix --> iterate over a copy: for x in lst[:]:
    |
    v
[5] Unexpected shared reference?
    Two variables point to the same list; changing one changes both.
    |
    +-- fix --> use lst.copy(), lst[:], or copy.deepcopy() for nested
```

# Quick Facts (Revision)

- list: ordered, mutable, allows duplicates, indexed by int.
- dict: key-value pairs, mutable, insertion-ordered (3.7+), keys must be hashable.
- tuple: ordered, immutable, allows duplicates, often used for fixed records.
- set: unordered, mutable, unique elements only, fast O(1) membership test.
- Slicing `[start:stop:step]` works on list, tuple, and str; stop is exclusive.
- Comprehensions: `[expr for x in iterable if cond]` for list; `{}` for dict/set.
- Mutable types (list, dict, set) cannot be dict keys or set members.
- `lst.sort()` sorts in place and returns None; `sorted(lst)` returns a new list.
