# C++ for Propulsion Enthusiasts

**Or, What They Should Have Taught You in ECE160 and ECE230**

[TOC]

## Introduction

Welcome to **C++ for Propulsion Enthusiasts!** This guide aims to bring you from
making basic Arduino sketches to being able to write fast, efficient, and
flight-ready C++ code. C++ is a very complex language that exposes a lot of
knobs and levers to the programmer in order to make it possible to write code
that does exactly what you want, regardless of how specific your needs are; for
that reason, this guide is going to be quite long and possibly quite boring to
people other than me. I've tried not to make things too dry wherever possible,
but it's definitely not going to be too fun to read through in one sitting. I
recommend going through one section at a time and spending a bit of time playing
with each topic before moving on.

This guide assumes you have a basic understanding of C/C++ program structure and
syntax, bytes and binary representation, and the basics of the Arduino framework
(e.g. what you would learn from ECE160). There are many ways to approach these
topics and many people more qualified to teach them than I am; see the Useful
Links section for guides I like. Knowledge of Java or other similar languages
may also be helpful.

It's worth noting that Arduino tends to smooth over a lot of the details of 
embedded systems. This leads to several compromises that may cause problems in
edge-case uses, so more performance- or functionality-critical projects might
want to consider using different frameworks. However, those frameworks tend to
be highly hardware-specific, difficult to learn, and don't provide many
device-support libraries, so Arduino tends to be the most practical for
competition-team projects. If you're interested in lower-level frameworks,
ECE230 provides a good introduction to what's involved in using those.

Also, for the purposes of documentation-browsing, Arduino is currently locked to
the C++11 standard; when browsing the C++ documentation, be wary of features
that are marked as available only in newer versions.

## Useful Links

* Official Arduino project book: https://www.uio.no/studier/emner/matnat/ifi/IN1060/v21/arduino/arduino-projects-book.pdf
* Binary tutorial: https://www.cmu.edu/gelfand/lgc-educational-media/digital-education-modules/dem-documents/new-the-world-of-the-internet-handouts.pdf
* C++ documentation: https://en.cppreference.com/w/
* Arduino documentation: https://docs.arduino.cc/
* PlatformIO documentation: https://docs.platformio.org/en/latest/
* Godbolt Compiler Explorer: https://godbolt.org/

# Part 1: The C++ Language

## Memory

> Note, if you have taken CSSE132 or equivalent a lot of this will be repeat
> information for you, feel free to skip ahead

Whenever you want to store a piece of data on a computer, regardless of any
other constraints, it has to live somewhere. In most modern languages, deciding
where an object has to live in memory is largely abstracted away; when you
create an object in Java or MATLAB, the language's runtime finds a free location
in the program's memory in which to store the object, marks that object in use,
and then seamlessly hands you back a reference to that memory. It then tracks
where you use that object, and as soon as you're done, it reclaims the memory
and makes it available to the rest of the program in a process called garbage
collection.

This is a wonderful system that makes programming easy, but it has downsides;
it requires a fair amount of work on the part of the computer to keep track of
all of the objects it's juggling at any given time. Additionally, there is added
uncertainty in the program's execution; the runtime decides when it wants to
sweep for unused projects in the background, so your program will periodically
have unexpected hitches in performance as memory is cleaned up.

### Static memory

In C, C++, and other non-garbage-collected languages, in contrast, memory
allocation is mostly manual. Variables declared at the top level of the program,
in global scope, have **static** storage duration; the compiler allocates them
a fixed location in program memory, which is only used for them and nothing
else:
```c++
// These objects will exist forever
int x = 3;
// Yes, even user-defined classes
MyClass obj(1, 2, 3, "abc");
```
Static-storage objects are unusual in that they have a defined initial value;
the C standard defines the program memory to be initialized with all zeroes, so
primitive objects like integers will always start with the value zero. (For
classes, initialization is a bit more complex; more to come later.) Because this
allocation happens at compile-time, we can consider static allocation to be
essentially free of performance cost.

### Stack memory

Variables declared inside a function, loop, or other construct are defined as
having **automatic** storage duration; in this guide, this will be referred to
by the more common colloquial term of being **on the stack**. The stack is a
region at the top of memory that gradually expands downward as variables are
allocated, like so:

```c++
// stack:
// (nothing)
// ============
// ... unallocated memory
// ...
void myfunc(int x) {
    int y = x + 3;
    // stack:
    // x
    // y
    // ============
    // ... unallocated memory
    // ...
    if(x > 0) {
        z = y - 4;
        // stack:
        // x
        // y
        // z
        // ============
        // ... unallocated memory
        // ...
    } // z deallocated
    // stack:
    // x
    // y
    // ============
    // ... unallocated memory, formerly z
    // ...
    for(int q = 0; q < 4; q++) {
        x = y - 4;
        // stack:
        // x
        // y
        // q (same memory that was used for z)
        // ============
        // ... unallocated memory
        // ...
    } // q deallocated
    // stack:
    // x
    // y
    // ============
    // ... unallocated memory, formerly z and q
    // ...
} // x and y deallocated
```

Note that memory on the stack is frequently reused, and there is no guarantee
(as there is for static variables) that the memory will be initialized with any
particular value. Therefore, whenever you place a primitive variable on the 
stack, it's essential that you initialize the variable with some value before
it's used. Most compilers will attempt to detect this and display a warning, but
it isn't always caught in obscure scenarios. Because allocating memory on the
stack only requires moving the "bar" in the above diagram (referred to as the
stack pointer), it can also be considered mostly "free" from a performance
perspective.

### Heap memory

The third way to allocate memory in C, C++ and related languages is on the
**heap**. Heap allocation is closer to what languages like Java do to allocate
memory; the program keeps track of which memory is available, and on-demand
hands out memory to functions that request it. In C++, the syntax for doing so
looks like this:

```c++
// Allocate 100 bytes and treat the resulting block as integers
// This is the old-school, C way to do things; you probably shouldn't use it in
// C++ in most cases
// Don't worry about the syntax here, we'll get to it in more detail later
int* mem1 = (int*) malloc(100);

// Allocate enough memory to store 25 integers (this is better; you don't need
// to care about how much space your compiler decides an integer needs)
// Unlike malloc, there are different operators for single items and arrays
int* mem2 = new int(5); // one integer that is equal to 5
int* mem3 = new int[25]; // 25 integers with unknown contents
```

However, unlike in Java and other garbage-collected languages, heap-allocated
variables are not tracked in any way once they're allocated. It is the
programmer's responsibility to ensure they release the memory once it's no
longer in use:

```c++
// Always use free() for malloc()
free(mem1);
// free() will leave the pointer pointing at unallocated memory; reset it to
// null to make it clear that it's no longer valid
mem1 = nullptr;

// Always use delete for new
delete mem2;
delete[] mem3;
// Delete also isn't guaranteed to automatically nullify, but some compilers
// might - don't count on it
mem2 = nullptr;
mem3 = nullptr;
```

Heap-allocating variables has several advantages. Because the memory is
allocated on-the-fly, we don't have to know at compile-time how much memory we
will need; for example, if we're writing a word processor, we can check how
large the document we're opening is and allocate just enough memory to store it.
We also can allocate memory in more complex patterns than we can on the stack;
for example, we might have a sensor-reading function that collects a large swath
of data and puts it in a heap-allocated queue; then, our data processing code
can independently take items off of that queue, analyze them, and then free them
once they are done.

However, heap allocation has a number of disadvantages. Figuring out where to
put memory has a cost in both performance and memory usage, especially on small
systems. Additionally, we only have a finite amount of memory; at any time a
call to `new` or `malloc` might fail and return `nullptr` or throw an error,
meaning that it couldn't find a place to put the requested object. This is
compounded by the fact that we have to manually free memory; if we forget to do
so, referred to as a "memory leak", we will gradually accumulate garbage in our
heap and eventually run out. For these reasons, we typically try to avoid using
heap allocation whenever possible in embedded code.

### Sidebar: Undefined Behavior

You may have noticed that at several points in this guide, I tell you not to do
things that will compile just fine and are perfectly valid code. Usually, this
means that doing so will cause **undefined behavior**. Here are a few common
examples of such cases:

* Putting a value larger than the maximum limits of the type into an integer
  variable
* Not returning from a function with a non-void return type
* Reading a stack- or heap-allocated variable without initializing it
* Using `nullptr` as a memory location
* Using a heap-allocated memory block of size zero
* Mixing `new` and `free` or `malloc` and `delete`

The only property of undefined behavior is that there is no limitation on what
it is allowed to do. The compiler may choose to do what you wanted, something
contrary to what you wanted, or something seemingly unrelated to what you typed;
all are fair game within the standard. In the C community, this property is
jokingly referred to as "nasal demons"; when faced with undefined behavior, it
is valid for a compiler to decide that your program should make demons fly out
of your nose. Here are a few memorable examples that I've encountered:

* Upon failing to include a `return` in a function, the compiler decided to run
  the function repeatedly forever instead of continuing to the next line.
* Upon attempting to place a floating-point infinity in an integer variable,
  the compiler would place the maximum integer there at compile-time but zero
  there at runtime.
* When compiling an `if`/`else` statement where the `else` branch contained
  undefined behavior, the compiler decided that the undefined behavior would be
  to imitate the result of the `if` branch, resulting in the if-statement being
  completely inconsequential.

In general, we almost never want to cause undefined behavior to occur. There are
cases where it is acceptable if we have a good idea of what our particular
compiler will choose to do, and occasionally it can even be used to hint to the
compiler that a particular section can be optimized away, but in general extreme
caution should be used in those scenarios.

## Pointers

You may have noticed in the previous section that we introduced a new piece of
syntax:

```c++
int* mem2 = new int(5);
```

This is a pointer; it is a datatype that refers to the memory location of
another piece of data, and is read as "pointer to int". We can get the location
of any variable with the `&` operator:

```c++
int x = 3;
int* pointer_to_x = &x;
```

We can also refer to the variable at a given location, known as dereferencing,
with the `*` operator:

```c++
int* pointer_to_y = new int(5);
int y = *location_of_y;
```

Pointers can be made to other pointers, at any level of nesting:

```c++
int x = 3;
int* px = &x;
int** ppx = &px;
int*** pppx = &ppx;
int y = ***pppx;
```

Pointers mostly behave like integers, with a handful of differences. They can be
assigned and compared as normal:

```c++
int x = 3;
int* px1 = &x;
int* px2 = px1;
if(px1 == px2) {
    // yes
}
```

We've mentioned the special value `nullptr` a few times; this is a constant
provided by the language that has the literal value of zero. Since zero is
considered "false" and all other integers considered "true", this means that
`if(ptr)` is a handy shortcut to check if a pointer is null:

```c++
int* x = (int*) malloc(4000000); // might run out of memory
if(x) {
    // do thing
} else {
    // out of memory error
}
```

Pointers may be created to any object, even ones that may be deallocated later;
a common pitfall is pointers to stack-allocated values that then outlive their
scope:

```c++
int* func() {
    int x = 3;
    return &x;
}

int* myptr = func();
*myptr = 3; // undefined behavior, probably crashes
```

A common use of pointers, especially in older C code, is to return multiple
values or large, unwieldy datatypes from a function:

```c++
int func(MyBuffer* buf) {
    *buf = ...
    if(/*ok*/) {
        return 0;
    } else {
        return -1;
    }
}

MyBuffer mybuf;
int errcode = func(&mybuf);
if(errcode) {
    // something went wrong
} else {
    // buffer has been filled
}
```

In general, though, this shouldn't be used without consideration; it makes code
harder to read and is prone to pitfalls if you don't think through your logic
carefully.

### Sidebar: `const`

Any variable in C or C++ can be declared as `const`. This simply means that it
can't be modified once created:

```c++
const int x = 3;
x ++; // error
```

Pointers can be `const` in multiple ways:

```c++
int a;
int b;
const int* x = &a; // Pointer to constant
x = &b; // ok
*x ++; // error
int* const x = &a; // Constant pointer to non-constant
x = &b: // error
*x ++; // ok
const int* const x = &a; // Constant pointer to constant
x = &b: // error
*x ++; // error
```

### Sidebar: References

Pointers have existed since the very beginning of the C language, but C++ added
an extra related type: references. These are declared like this:

```c++
int x;
int& rx = x;
```

These types behave exactly like pointers, but automatically include dereference
operators when used. They also can't be nulled. Generally, I don't like these
types very much, since they obscure what's happening under the hood: because
they appear as values while actually being pointers, it's easy to do things like
trying to copy them by value and accidentally only copy the reference. However,
there is one scenario where they allow a very useful optimization. If you pass
a large user-defined type to a function, it has to be copied in its entirety:

```c++
// copies t, which might be hundreds of bytes
void func(MyType t) {
    ...
}

MyType x;
func(x);
```

By changing the parameter to a `const MyType&`, the syntax for calling the
function and using the parameter are unchanged, but no copy occurs:

```c++
// no copy
void func(const MyType& t) {
    ...
}

MyType x;
func(x);
```

This can end up increasing performance by a substantial amount in some cases.
However, modern C++ compilers have gotten very good at optimizing out
pass-by-value under the hood, so this isn't always necessary either.

## Classes

**Classes** are the part of C++ syntax that will look most familiar to Java
programmers. A class represents a user-defined type of object which may be
reused in multiple places.

> Classes are by far the most sophisticated piece of syntax added by C++. Grab
> yourself a snack and a beverage before starting this section, there's going to
> be a lot to go over here.

Defining a class looks like this:

```c++
class Car {
    public: // 1
        int wheels; // 2
        Car(): wheels(4) {} // 3
        Car(int wheels): wheels(wheels) {
            // do things on creation
        }

        void drive() { // 4
            // do something
        }
}; // 5

Car myCar; // 6a
Car yourCar(3); // 6b
Car theirCar{3}; // 6c
yourCar = Car(4); // 6d
```

There's a lot to take in here. The numbered comments are the key points:

1. **Access modifier.** If you've used Java you may be used to these being placed in
   front of every member; in C++, they act like sections instead. Valid options
   are:

    * `public`: Anyone can use.
    * `protected`: Only this class and subclasses can use.
    * `private`: Only this class can use. This is the default.

2. **Member variable.** This acts like a normal variable and can be accessed
   like `myCar.wheels`.

3. **Constructor.** This is a special function with no return type that creates
   an instance of the class. It can be followed by a colon, which defines a list
   of member and/or superclass constructors that should be called. A lot of the
   time, you can define a constructor's entire behavior in this list and have
   nothing in the function body.

4. **Member function.** This acts *mostly* like a normal function, with a few
   exceptions. It can be accessed like `myCar.drive()`.

5. Unlike most blocks using `{...}`, classes always end with a semicolon. This
   is for somewhat archaic C reasons.[^1]

6. Object declaration. Once you've created a class, you can use it like any
   other type. Classes can be created in a couple of ways:
    * 6a: Just defining an object like this calls the constructor with no
      arguments.
    * 6b: Calls the constructor with the given arguments. Note that this doesn't
      work unless there is at least one argument.[^2]
    * 6c: Same as 6b, but works in a very slightly different set of
      circumstances (works with no arguments, but has weird behavior with
      container types and public members). The differences are weird and
      confusing and I don't think anyone fully understands them.
    * 6d: You can also call the constructor manually to create an object without
      creating a variable for it.

### Sidebar: `struct`

You may occasionally see classes declared with `struct Car {...}` instead of
`class Car {...}`. `struct` is a carried-over keyword from C, which doesn't have
`class`; in C++, it is identical to `class` except that the default access
modifier is `public` instead of `private`.

### Sidebar: Member-dereference operator

If you have a pointer to an object of type `Car`, you can access its members via
the `->` operator:

```c++
Car* ptrToMyCar = &myCar;
ptrToMyCar->drive();
```

This is identical to typing `(*ptrToMyCar).drive()`, just easier to deal with.

### `this`

Like in many languages, C++ provides a `this` keyword which can be used inside
a class. `this` is always a pointer to the current object. In most cases, you
don't need to use it -- using a member variable inside a member function implies
`this->` -- but it may be useful in some cases to clarify what a variable refers
to.

#### Sidebar: `const` member functions

You can suffix a member function with `const`:

```c++
class Car {
    public:
        void drive() const {
            // ...
        }
};
```

This makes the `this` pointer for that function a pointer-to-const; all members
of the class are considered `const` and only functions with the `const`
qualifier can be called. It's generally good form to add `const` to any function
that doesn't modify the class, as it makes optimization easier for the compiler
and is a good reassurance to future programmers that your function doesn't do
anything unexpected.

Note that there are some holes in this restriction due to the subtleties of
pointer-`const` syntax. Members which themselves are pointers will be made
`const`-pointer rather than pointer-to-`const`, so the things they point to may
still be modified; this includes members of the class itself, since the compiler
has no way to tell what they point to ahead of time. You can use this to
underhandedly modify a class inside a const function, but you probably shouldn't
unless you have a very good reason to.

### Inheritance

Similar to Java, classes in C++ can **inherit** the behaviors of other classes.
This is used when a given type -- the **subclass** -- is some specialized type
of another type -- the **superclass**.  The syntax for doing so looks like this:

```c++
class Ford: public Car {
    public:
        Ford() { }
        float getMiles() { // new function
            /// ...
        }
        void drive() { // overridden function
            // ...
        }
};
```

Note that the inheritance includes an access modifier; this gets applied on top
of any preexisting access modifiers in the superclass. If you inherit from a
class with public members as `private`, all of its members will be `private`
within your class.

#### Conversion

One of the common uses for an inherited class is to allow multiple objects to
fit into the same "slot". In the example above, you might have a preexisting
function that takes a Car, and you want to be able to use your Ford in it. There
are two different ways to do this:

* **Conversion of pointers or references.** A `Car*` or `Car&` may be made to point
  to a `Ford` without issue.
* **Conversion of values.** C++ will also allow you to place a ***value*** of
  type `Ford` into a variable of type `Car`. **THIS IS USUALLY BAD. DO NOT DO**
  **IT.** This is prone to a bug known as "slicing"; if `Ford` adds extra member
  variables to `Car`, those variables won't fit in the space allocated for `Car`
  and functions that try to use those variables will instead read garbage. In
  this case, it's fine since `Ford` doesn't add any new member variables, only
  functions, but you shouldn't count on this. 

#### `virtual`

Unlike in a lot of other languages, functions in C++ classes can't be overriden
by default in the way you might expect. The code above actually has a subtle
bug; we've overridden `drive()` in the `Ford` subclass, but if we store a
pointer to a `Ford` in a `Car*`, the compiler will still use the `Car` version
of `drive` for that object. This is because determining the correct function to
use for an inherited class is a very, very small amount of additional overhead,
and C++ is strongly averse to adding additional overhead if there is any
possible scenario where it might not be needed. This makes it good for
high-performance use cases like embedded systems, but can lead to a lot of weird
edge-case behavior like this.

In order to get Java-style function overriding, the function should be prefixed
with the keyword `virtual`:


```c++
class Car {
    public:
        virtual void drive() {
            // ...
        }
};
```

This keyword creates a hidden extra member to the class called a `vtable`; this
is a pointer to a list of functions that are overridden in this particular
object. Then, when `drive()` is called, the program will check at runtime which
table this particular object uses and call the `drive()` function from that
table. As you might expect, this adds a bit of overhead, so it's best to avoid
using it too frequently; however, compilers are pretty good at optimizing it out
if the type doesn't actually change at runtime, so it's not the end of the
world.

If you want subclasses to be forced to implement a virtual function as in Java's
abstract methods, you can specify it as **pure virtual** like so:

```c++
virtual void drive() = 0;
```

Any class with a pure-virtual function cannot be instantiated; its subclasses
must add their own implementations.

### Other special functions

Besides the constructor, there are a few other special-case functions that are
helpful to be aware of. Most are given some reasonable default implementation
automatically, so you don't need to worry about them too much in most cases.

#### Copy constructor

The copy constructor is just a normal constructor that takes only one argument
which is a reference to its own class. For example, both of these are valid:

```c++
Car(const Car& other) {}
Car(Car& other) {}
```

#### Move constructor

This is very similar to the copy constructor, but uses a brand-new type in C++11
called an "rvalue reference". Essentially, it's used for when an object can't be
copied but might be moved, for example a class that handles some external
resource; it's not terribly common.

```c++
Car(Car&& other) {}
```

#### Copy and move assignment

These are almost the same as the copy and move constructor, but are used for the
` = ` operator instead of construction. They are an example of operator
overloading, which we'll discuss later.

```c++
Car operator= (const Car& other) {}
Car operator= (Car& other) {}
Car operator= (Car&& other) {}
```

#### Destructor

This is probably the special function you'll use the most. The destructor is a
piece of code that gets called whenever the object goes out of scope or is
deleted; here, you should do things like free memory, release resource handles,
etc. It's defined like this:

```c++
~Car() {}
```

#### The Rule of Five

The Rule of Five is a rule of thumb for using special functions, which states
that if you provide your own implementation for any one of the above functions,
you should provide an implementation for all of them:

```c++
~Car() {}
Car(const Car& other) {}
Car operator= (const Car& other) {}
Car(Car&& other) {}
Car operator= (Car&& other) {}
```

Luckily, if you don't need all of these operations, you don't have to take the
time to write all of them; you can also specify them as deleted:

```c++
Car operator= (const Car& other) = delete;
```

Most of the time, it's best to write your code such that none of these functions
are needed; some people refer to this as the "rule of zero."

#### Sidebar: the Rule of Five with virtual functions

If you expect other people to inherit from your class, leaving the rule-of-five
functions unmodified can be risky. Recall that to override functions for base
class pointers, the base functions have to be `virtual`. If someone else extends
your class with a class that requires a destructor, then tries to delete it from
a pointer to the base class, the destructor won't be called and memory will be
leaked. To solve this, you can declare the rule-of-five functions as `virtual`
and define them as default:

```c++
virtual Car operator= (const Car& other) = default;
```

[^1]: The reason this exists is because it's legal to declare a class and
an object in the same statement, e.g. `class Car {...} myCar(3);` Basically
nobody uses this syntax anymore, so don't worry about it too much.

[^2]: If you try to define an object using syntax like `Car myCar()`, C++ will
instead declare a function that returns `Car`. This is the issue that the new
syntax `Car myCar{}` attempts to fix, but that isn't exactly free of issues
either.