# Classes and Object-Oriented Programming

- A class is a blueprint that defines attributes and behavior; an instance is a concrete object created from that blueprint.
- Python supports single and multiple inheritance, with Method Resolution Order (MRO) determining which method is called.
- Dunder (magic) methods let objects integrate with Python's built-in syntax -- operators, iteration, string conversion, comparison.

# Architecture

```text
+---------------------------+
|       type (metaclass)    |    <-- creates classes themselves
+---------------------------+
            |
            v
+---------------------------+
|     class Dog             |    <-- blueprint (class object)
|---------------------------|
|  class var: species       |    <-- shared across all instances
|  __init__(self, name)     |
|  bark(self)               |
|  @classmethod from_str()  |
|  @staticmethod info()     |
+---------------------------+
      /           \
     v             v
+-----------+  +-----------+
| instance  |  | instance  |     <-- concrete objects
| name="Rex"|  | name="Bo" |     <-- each has own instance vars
+-----------+  +-----------+


Inheritance chain (MRO):

+----------+     +----------+
|  Animal  |     |  Mixin   |
+----------+     +----------+
      \              /
       v            v
    +----------------+
    |     Dog        |    MRO: Dog -> Animal -> Mixin -> object
    +----------------+
           |
           v
    +----------------+
    |   instance     |
    +----------------+
```

# Mental Model

```text
Object creation lifecycle:

  [1] Dog("Rex")
       |
       v
  [2] Dog.__new__(cls)         --> allocates memory, returns raw instance
       |
       v
  [3] Dog.__init__(self, name) --> initializes attributes (self.name = "Rex")
       |
       v
  [4] instance ready           --> self is now a fully initialized Dog object


Attribute lookup order:

  instance.__dict__  -->  class.__dict__  -->  parent class(es).__dict__  -->  object
       (per-object)       (shared)              (via MRO)                     (base)
```

```python
class Animal:
    kingdom = "Animalia"              # class variable -- shared

    def __init__(self, name):
        self.name = name              # instance variable -- per object

    def speak(self):
        raise NotImplementedError

class Dog(Animal):
    def __init__(self, name, breed):
        super().__init__(name)        # call parent __init__
        self.breed = breed

    def speak(self):
        return f"{self.name} says Woof!"

    def __repr__(self):
        return f"Dog(name={self.name!r}, breed={self.breed!r})"

    def __str__(self):
        return f"{self.name} ({self.breed})"

rex = Dog("Rex", "Labrador")
print(rex)            # Rex (Labrador)        -- __str__
print(repr(rex))      # Dog(name='Rex', breed='Labrador') -- __repr__
print(rex.speak())    # Rex says Woof!
print(rex.kingdom)    # Animalia              -- found via class
```

# Core Building Blocks

### Class Definition and `__init__`

- `class ClassName:` defines a new class; convention is CapitalCase.
- `__init__(self, ...)` is the initializer, called after the instance is created.
- `self` refers to the current instance -- Python passes it automatically.
- `__init__` does NOT create the object; `__new__` does (rarely overridden).

```python
class Point:
    def __init__(self, x, y):
        self.x = x      # instance attribute
        self.y = y

p = Point(3, 4)
```

Related notes: [001-variables-and-types](./001-variables-and-types.md), [003-functions](./003-functions.md)

### Instance vs Class Variables

- Instance variables: defined on `self` inside `__init__`, unique per object.
- Class variables: defined in the class body, shared across all instances.
- Mutable class variables (lists, dicts) are a common pitfall -- all instances share the same object.
- Use `type(self).var` or `ClassName.var` to access class variables explicitly.

```python
class Counter:
    count = 0                  # class variable

    def __init__(self):
        Counter.count += 1     # modify via class name
        self.id = Counter.count  # instance variable
```

Related notes: [001-variables-and-types](./001-variables-and-types.md), [004-data-structures](./004-data-structures.md)

### Methods -- Instance, Class, Static

- **Instance method**: takes `self`, operates on the instance.
- **`@classmethod`**: takes `cls`, operates on the class (often used for alternative constructors).
- **`@staticmethod`**: no `self` or `cls`, a plain function namespaced inside the class.

```python
class Date:
    def __init__(self, year, month, day):
        self.year = year
        self.month = month
        self.day = day

    def display(self):                          # instance method
        return f"{self.year}-{self.month:02d}-{self.day:02d}"

    @classmethod
    def from_string(cls, date_str):             # alternative constructor
        y, m, d = map(int, date_str.split("-"))
        return cls(y, m, d)

    @staticmethod
    def is_valid(date_str):                     # utility, no instance/class access
        parts = date_str.split("-")
        return len(parts) == 3
```

Related notes: [003-functions](./003-functions.md), [009-decorators-and-generators](./009-decorators-and-generators.md)

### Inheritance and MRO

- `class Child(Parent):` -- single inheritance.
- `class Child(Parent1, Parent2):` -- multiple inheritance.
- `super()` delegates to the next class in the MRO, not always the direct parent.
- MRO follows C3 linearization: inspect with `ClassName.__mro__` or `ClassName.mro()`.
- Python resolves methods by walking the MRO top to bottom and returning the first match.

```python
class A:
    def greet(self):
        return "A"

class B(A):
    def greet(self):
        return "B -> " + super().greet()

class C(A):
    def greet(self):
        return "C -> " + super().greet()

class D(B, C):
    pass

print(D().greet())      # B -> C -> A
print(D.__mro__)        # D -> B -> C -> A -> object
```

Related notes: [003-functions](./003-functions.md)

### Dunder / Magic Methods

- Control how objects behave with built-in operations and syntax.
- `__str__` -- human-readable string (`print()`, `str()`).
- `__repr__` -- unambiguous string for debugging (`repr()`), shown in REPL.
- `__len__` -- called by `len()`.
- `__eq__`, `__lt__`, `__le__`, etc. -- comparison operators.
- `__getitem__`, `__setitem__` -- bracket access (`obj[key]`).
- `__iter__`, `__next__` -- make objects iterable.
- `__add__`, `__mul__` -- arithmetic operators.
- `__contains__` -- `in` operator.
- `__call__` -- make instances callable like functions.

```python
class Vector:
    def __init__(self, x, y):
        self.x = x
        self.y = y

    def __add__(self, other):
        return Vector(self.x + other.x, self.y + other.y)

    def __eq__(self, other):
        return self.x == other.x and self.y == other.y

    def __repr__(self):
        return f"Vector({self.x}, {self.y})"

v = Vector(1, 2) + Vector(3, 4)   # Vector(4, 6)
```

Related notes: [009-decorators-and-generators](./009-decorators-and-generators.md), [004-data-structures](./004-data-structures.md)

### Properties -- `@property`, Getter/Setter

- `@property` turns a method into a read-only attribute.
- Use `@name.setter` to allow assignment.
- Encapsulates validation logic without changing the calling interface.

```python
class Circle:
    def __init__(self, radius):
        self._radius = radius       # convention: underscore = "private"

    @property
    def radius(self):
        return self._radius

    @radius.setter
    def radius(self, value):
        if value < 0:
            raise ValueError("Radius cannot be negative")
        self._radius = value

    @property
    def area(self):                  # computed, read-only
        return 3.14159 * self._radius ** 2

c = Circle(5)
c.radius = 10      # calls setter
print(c.area)       # 314.159 -- computed on access
```

Related notes: [009-decorators-and-generators](./009-decorators-and-generators.md)

### Dataclasses (Python 3.7+)

- `@dataclass` auto-generates `__init__`, `__repr__`, `__eq__` from field definitions.
- Reduces boilerplate for classes that primarily hold data.
- `field(default_factory=list)` for mutable defaults.
- `frozen=True` makes instances immutable (generates `__hash__` too).
- `order=True` generates comparison methods (`__lt__`, `__le__`, etc.).

```python
from dataclasses import dataclass, field

@dataclass
class Employee:
    name: str
    department: str
    salary: float = 50000.0
    skills: list = field(default_factory=list)

@dataclass(frozen=True)
class Point:
    x: float
    y: float

e = Employee("Alice", "Engineering", skills=["Python", "K8s"])
print(e)  # Employee(name='Alice', department='Engineering', salary=50000.0, skills=['Python', 'K8s'])
```

Related notes: [001-variables-and-types](./001-variables-and-types.md), [009-decorators-and-generators](./009-decorators-and-generators.md)

---

# Troubleshooting Flow (Quick)

```text
Problem: unexpected behavior with classes or inheritance
    |
    v
[1] AttributeError on instance?
    print(vars(obj)) or obj.__dict__
    |
    +-- attribute missing --> check __init__, did you assign to self?
    |
    v
[2] Wrong method being called (inheritance)?
    print(ClassName.__mro__)
    |
    +-- unexpected order --> check multiple inheritance, C3 linearization
    +-- forgot super() --> parent __init__ not called, attributes missing
    |
    v
[3] Mutable class variable shared across instances?
    print(id(obj1.list_attr) == id(obj2.list_attr))
    |
    +-- True --> move to __init__ as instance variable
    |
    v
[4] __str__ vs __repr__ confusion?
    print() uses __str__, REPL/containers use __repr__
    |
    +-- define __repr__ first (more important), __str__ for user-facing
    |
    v
[5] @property not working?
    check you used @property, not calling as method (no parentheses)
```

# Quick Facts (Revision)

- `__init__` initializes; `__new__` creates -- override `__new__` only for immutable types or metaclasses.
- Instance variables live in `obj.__dict__`; class variables live in `ClassName.__dict__`.
- MRO follows C3 linearization: inspect with `ClassName.__mro__` or `help(ClassName)`.
- `super()` in Python 3 needs no arguments -- it follows MRO, not just the direct parent.
- Always define `__repr__`; define `__str__` only when a user-friendly format differs.
- `@dataclass` auto-generates `__init__`, `__repr__`, `__eq__` -- use `frozen=True` for immutability.
- Name mangling: `__var` becomes `_ClassName__var` -- discourages (does not prevent) external access.
- `isinstance(obj, Class)` checks inheritance chain; `type(obj) is Class` checks exact type.
