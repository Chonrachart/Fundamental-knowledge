# Strings and Arrays

- Bash has no typed data structures; every variable is a string, and arrays are ordered lists of strings.
- Parameter expansion (`${var...}`) is the primary mechanism for slicing, searching, and transforming string and array values.
- Quoting (`"$var"`, `"${arr[@]}"`) is critical -- unquoted expansions undergo word splitting and globbing.

# Architecture

```text
                         Bash Variable Storage
  +-----------------------------------------------------------------+
  |                                                                 |
  |   Scalar (string)             Indexed Array                     |
  |   +------------------+       +-----+-----+-----+-----+-----+   |
  |   | name = "hello"   |       |  0  |  1  |  2  |  3  |  4  |   |
  |   +------------------+       |"one"|"two"|"tre"|     |     |   |
  |                               +-----+-----+-----+-----+-----+   |
  |   ${name}  --> "hello"        ${arr[0]}  --> "one"               |
  |   ${#name} --> 5              ${arr[@]}  --> "one" "two" "tre"   |
  |                               ${#arr[@]} --> 3                   |
  |                                                                 |
  |   Associative Array (declare -A)                                |
  |   +----------+----------+----------+                            |
  |   | key1     | key2     | key3     |                            |
  |   | "val1"   | "val2"   | "val3"   |                            |
  |   +----------+----------+----------+                            |
  |   ${map[key1]} --> "val1"                                       |
  |   ${!map[@]}   --> "key1" "key2" "key3"  (all keys)             |
  +-----------------------------------------------------------------+

  Parameter Expansion Operators:
  +----------------------------+------------------------------------+
  | ${var:offset:length}       | substring / array slice            |
  | ${var#pattern}             | remove shortest prefix             |
  | ${var##pattern}            | remove longest prefix              |
  | ${var%pattern}             | remove shortest suffix             |
  | ${var%%pattern}            | remove longest suffix              |
  | ${var/old/new}             | replace first match                |
  | ${var//old/new}            | replace all matches                |
  | ${var:-default}            | use default if unset/empty         |
  | ${var:+alternate}          | use alternate if set               |
  +----------------------------+------------------------------------+
```

# Mental Model

```text
Parameter expansion decision tree:

  ${var...}
      |
      +-- :offset:length --> substring / slice
      |
      +-- #  / ## --------> remove prefix  (# = shortest, ## = longest)
      |
      +-- %  / %% --------> remove suffix  (% = shortest, %% = longest)
      |
      +-- /old/new -------> replace first match
      +-- //old/new ------> replace all matches
      |
      +-- :-default ------> fallback value if unset or empty
      +-- :=default ------> assign default if unset or empty
      +-- :+alternate ----> substitute if set and non-empty
      +-- :?error --------> abort with error if unset or empty
```

```bash
path="/usr/local/bin/deploy.sh"

# prefix removal: strip everything up to last /
echo "${path##*/}"         # deploy.sh

# suffix removal: strip everything from last /
echo "${path%/*}"          # /usr/local/bin

# suffix removal: strip file extension
echo "${path%.sh}"         # /usr/local/bin/deploy

# replacement
echo "${path/local/share}" # /usr/share/bin/deploy.sh
```

# Core Building Blocks

### Strings

- Bash has no separate string type; all scalar variables hold strings.
- Concatenation: `"$a$b"` or `result="${first}_${second}"`.
- `${#var}` -- length of the string in characters.
- Always double-quote string variables to prevent word splitting: `"$var"`, not `$var`.

```bash
first="hello"
second="world"
combined="${first} ${second}"
echo "$combined"       # hello world
echo "${#combined}"    # 11
```

- Single quotes preserve literals: `'$var'` prints `$var`, not its value.
- `$'...'` supports escape sequences: `$'\n'` = newline, `$'\t'` = tab.

Related notes: [001-variables-and-expansion](./001-variables-and-expansion.md)

### Arrays

- Indexed array: `arr=(a b c)` -- zero-based integer indices.
- Access single element: `${arr[0]}`.
- All elements: `${arr[@]}` (each element as separate word) or `${arr[*]}` (all as one word).
- Length: `${#arr[@]}` -- number of elements.
- Append: `arr+=("new")`.
- Delete element: `unset 'arr[2]'` -- leaves a gap (does not reindex).
- Associative array: `declare -A map; map[key]="value"` -- requires explicit declaration.

```bash
files=(*.txt)
echo "${files[0]}"       # first .txt file
echo "${#files[@]}"      # count of .txt files

# iterate safely (handles spaces in filenames)
for f in "${files[@]}"; do
    echo "$f"
done

# associative array
declare -A colors
colors[red]="#ff0000"
colors[blue]="#0000ff"
echo "${colors[red]}"    # #ff0000
echo "${!colors[@]}"     # red blue  (all keys)
```

Related notes: [002-control-flow](./002-control-flow.md)

### Substring and Slicing

- `${var:offset}` -- from offset to end of string.
- `${var:offset:length}` -- extract length characters starting at offset.
- Negative offset: `${var: -3}` -- last 3 characters (space before `-` is required).
- Array slice: `${arr[@]:offset:length}` -- extract a range of elements.

```bash
s="hello world"
echo "${s:0:5}"       # hello
echo "${s:6}"         # world
echo "${s: -5}"       # world

arr=(a b c d e)
echo "${arr[@]:1:3}"  # b c d
```

Related notes: [001-variables-and-expansion](./001-variables-and-expansion.md)

### Pattern-Based Manipulation

- Prefix removal: `${var#pattern}` (shortest), `${var##pattern}` (longest / greedy).
- Suffix removal: `${var%pattern}` (shortest), `${var%%pattern}` (longest / greedy).
- Replacement: `${var/pattern/replacement}` (first), `${var//pattern/replacement}` (all).
- Case conversion (Bash 4+): `${var^^}` (uppercase), `${var,,}` (lowercase), `${var^}` (first char upper).
- Patterns use glob syntax (`*`, `?`, `[...]`), not regex.

```bash
file="archive.tar.gz"

# prefix removal
echo "${file#*.}"      # tar.gz   (shortest: remove up to first .)
echo "${file##*.}"     # gz       (longest: remove up to last .)

# suffix removal
echo "${file%.*}"      # archive.tar  (shortest: remove from last .)
echo "${file%%.*}"     # archive      (longest: remove from first .)

# replacement
version="v1.2.3"
echo "${version//./-}"  # v1-2-3  (replace all dots with dashes)

# case conversion
name="hello"
echo "${name^^}"        # HELLO
echo "${name^}"         # Hello
```

Related notes: [001-variables-and-expansion](./001-variables-and-expansion.md), [005-errors-and-exit-codes](./005-errors-and-exit-codes.md)

---

# Troubleshooting Guide

```text
Problem: unexpected behavior with strings or arrays
    |
    v
[1] Is the variable quoted?
    echo "$var"  vs  echo $var
    |
    +-- unquoted --> word splitting and globbing may alter the value
    |                fix: always use "$var" and "${arr[@]}"
    |
    v
[2] Array acting like a scalar?
    echo $arr  vs  echo "${arr[@]}"
    |
    +-- $arr only returns ${arr[0]} --> use "${arr[@]}" for all elements
    +-- spaces in elements breaking loops --> quote: for x in "${arr[@]}"
    |
    v
[3] Parameter expansion not working as expected?
    |
    +-- glob pattern vs regex --> expansions use glob (*, ?), not regex
    +-- negative offset error --> ${var: -3} needs a space before the dash
    +-- unset variable silent --> add set -u or use ${var:?error message}
    |
    v
[4] Associative array returning empty?
    |
    +-- missing declare -A --> associative arrays require explicit declaration
    +-- key has spaces      --> quote the key: ${map["my key"]}
```

# Quick Facts (Revision)

- All Bash variables are strings; arrays are ordered lists of strings.
- `${#var}` = string length; `${#arr[@]}` = array element count.
- `${var:offset:length}` works for both strings (characters) and arrays (elements).
- `#` removes prefixes, `%` removes suffixes -- mnemonic: `#` is before `%` on a keyboard.
- Single `#`/`%` = shortest match (non-greedy); double `##`/`%%` = longest match (greedy).
- `${var/old/new}` replaces first; `${var//old/new}` replaces all.
- Always quote: `"$var"` for strings, `"${arr[@]}"` for arrays -- prevents word splitting.
- Associative arrays require `declare -A`; indexed arrays do not need `declare -a`.
