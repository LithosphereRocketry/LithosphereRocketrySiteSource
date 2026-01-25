# A Guide to the Deep End

**Or, Learning Programming via the C Language**

[TOC]

## Introduction
## Setting Up

Before we can start programming, we'll need to set up a few tools we'll be
using. My computer runs the Linux operating system, and Linux is probably the
easiest OS to write C code on, so this ?book? will assume that you're using Linux.
If you aren't on a Linux computer, though, don't despair - see the below
section.

### Using non-Linux OSes

#### Windows

On Windows, as of time of writing, the easiest way to set up the tools used here
is via the Windows Subsystem for Linux (WSL). This is a lightweight, text-only
Linux virtual machine that is simple to set up and gives you a mostly
full-featured Linux environment. To use it, just install WSL from the Windows
store, and then install your preferred Linux flavor. (Ubuntu is a popular option
if you can't decide.)

Another option is MSYS2, which runs more-or-less natively in Windows and
provides a Linux-like terminal interface with open-source utilities. This will
also work fine, but requires a bit more fiddling and configuration. I won't be
covering it here, but it should be usable for all examples in this ?book?.

#### Mac

Mac users are in luck - MacOS is _very_ similar to Linux in the ways that matter
to us (rather, they have a common ancestor in Unix.) However, Apple really likes
to ship outdated versions of the open-source tools this ?book? uses, and does
other shady things like making the `gcc` command point to the notably-not-GCC
`clang` compiler. The default versions of the tools _should_ work fine, but
you may want to look into installing newer versions from the Homebrew package
manager. I haven't used a Mac in a long time so this is outside my comfort zone,
but there's lots of Mac developers out there so there's plenty of resources to
refer to.

#### ChromeOS

ChromeOS is, in theory, easy, because it's already based on Linux. However,
Google does its best to obscure everything actually running on the computer and 
direct you to use a webpage instead, so getting to an actual Linux terminal is
a challenge. There are various workarounds, but they aren't well supported and
probably aren't possible if you're on an organization-managed Chromebook like
a school computer. You're on your own here.

Of course, on any of these systems, it's always an option to spin up a
full-featured Linux virtual machine through something like VirtualBox. This will
give you a full desktop environment as if you were using a full Linux computer,
but is a bit clunkier than WSL or a native terminal.

### Required tools

Regardless of operating system, there are a few tools you'll need to proceed.
These are as follows:

**A Unix terminal.** This is covered above. If you're on Linux or Mac you have
this already, or if you're on Windows it's provided by WSL or MSYS2. There are
several different flavors of "shell," or terminal interface, whose differences 
won't really matter here - if for some reason you have to choose one, use
`bash`.

**A C compiler.** All examples in this ?book? have been tested using the GCC
compiler. This is a popular open-source compiler and is generally quite good,
as well as supporting a very wide range of systems. If you're on Ubuntu Linux,
you can install GCC by typing `sudo apt install gcc` into the terminal; on other
flavors or operating systems, there will be a similar command.

To check you've completed this step, type `gcc --version` into your terminal.
You should see something like this:

```
gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0
Copyright (C) 2021 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
```

**A debugger.** The debugger is an important tool for understanding what
programs are doing. If you're using GCC you want its counterpart GDB, which is
installed the same way (`sudo apt install gdb` or equivalent). If you're using
LLVM, you may have an easier time with its equivalent `lldb` - a few commands
are mildly different but the differences are mostly google-able.

To check you've completed this step, type `gdb -v` into your terminal. You
should see something like this:

```
GNU gdb (Ubuntu 12.1-0ubuntu1~22.04.2) 12.1
Copyright (C) 2022 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
```

**A Make program** compatible with GNU Make. On most Unix systems this can be
installed under the name `make`. This is a tool which automates the build
process for more complex programs.

You know the story by now; type `make -v` into your terminal. You should see
something like this:

```
GNU Make 4.3
Built for x86_64-pc-linux-gnu
Copyright (C) 1988-2020 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
```

**An editor.** Editors are the source of many religious wars in the programming
community. Pick one that you like; Visual Studio Code is a popular option that
has a friendly interface if you're not a Linux diehard. Or try `emacs` or `vim`
for the full old-school-C-developer experience. Programs are just text - you
can edit your code in Microsoft Word or Notepad if you want to (but don't).

## Chapter 0: Background

### What is a computer?

If you're reading a ?book? on learning to program, chances are good that you've
used a computer. Computers are how we write books, manage our money, keep in
touch with friends, and a million other day-to-day things, yet in all of these
applications they act as sort of a magic box, where we put information in and
get information out without ever having to think about what happens in between.
So what does a computer actually do?

Conceptually, a computer is very simple: it's a machine that follows extremely
specific instructions. Let's imagine you are trying to make yourself a delicious
plate of spaghetti for dinner. Some instructions for this task might look like
this:

* Fill a pot with water.
* Add some salt to the water.
* Heat the water to a boil.
* Put pasta in the water.
* Wait around 10 minutes.
* When the pasta is cooked to taste, strain and serve.

These are great instructions for a human, but if a computer were trying to make
you pasta, it would have no idea where to start. What pot should it use, with 
how much water? How much salt? How much pasta? How does it know that the water
is boiling? What does "to taste" even mean?

Alright, maybe cooking isn't the best example. Let's take a more reasonable
example:

### Side note: numeric bases and binary

As a human in the modern industrialized world, you probably will have learned
that numbers go like this:

```
0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 ...
```

In particular, we have unique symbols for the first ten numbers, and then we
start adding new symbols to the left of the number and start over. We call this
decimal or "base ten". A computer (with some unimportant exceptions) only has
two unique symbols - on and off, or 1 and 0. Therefore, numbers internal to a
computer use binary or base two, which works just like our normal decimal system
except that the rollover happens at two instead of ten:

```
0, 1, 10, 11, 100, 101, 110, 111, 1000, 1001, 1010 ...
```

In general, these numbers work just like decimal, and are ideal for implementing
out of actual circuits - except that instead of a ones, tens, and hundreds 
place, you have a ones, twos, fours, eights... place. However, you may notice
that they require a lot of space when written out for a human. To save space we
often abbreviate binary using hexadecimal or base sixteen, with the letters A
thru F providing the additional six digits:

```
0, 1, 2, 3, 4, 5, 6, 7, 8, 9, A, B, C, D, E, F, 10, 11, 12 ...
```

Since sixteen is `10000` in binary, each hexadecimal digit is exactly equivalent
to four binary digits, so round numbers in binary are also round numbers in
hexadecimal and vice versa. In contrast, these numbers' decimal representations
are often unhelpful:

```
1000000000000000000000000 binary
=
1000000 hexadecimal
=
16777216 decimal
```

It's possible to go an entire programming career without having to use binary
or hexadecimal, but they're useful to be aware of since their closeness to the
hardware representation can allow for some handy optimizations from time to
time. They also let you understand some of the great mysteries of the computing
world, like why your hard drive is the wrong size.*

\* Hard drives are advertised in decimal units - a gigabyte on a hard drive
label is exactly 1,000,000,000 bytes. However, most operating systems report
file sizes in slightly strange binary units - like the SI prefixes, but fudged
to be closer to round binary numbers, with prefixes separated by a factor of
1024 (10000000000 in binary) instead of a factor of 1000. This means that a 1000
gigabyte hard drive, which contains exactly 1,000,000,000,000 bytes, has
976,562,500 ki**bi**bytes, or about 953,674 me**bi**bytes, or about 931
gi**bi**bytes. Operating systems confusingly report these values without making
it clear that they're talking about binary SI sizes, making it look like you got
short-changed by a few percent.

### Languages, compilation and machine code

If you've ever studied grammar in any human language, you may be aware that the
way we humans communicate is often loose and confusing, which is the opposite
of what we want for our cold calculating machines. Therefore, to give
instructions to a computer, we have to speak to it in strictly defined
programming languages that it can understand in a clear and deterministic way.*
However, even these strict languages are still tailored for human usage, and
our computers actually understand something known as _machine code_ - a tightly
optimized sequence of binary data where very little space is wasted.

In many languages - especially those used for low-performance tasks like
webpages - the human-readable code is _interpreted_**, where a machine-code
program comprehends the written program code and then runs it in its own
imagined universe. However, in more performance-constrained applications, it's
more common for code to be _compiled_, where the human-readable code is
translated into machine code beforehand and the machine code is run directly on
the processor. The language we'll be using, C, is strictly a compiled language:
we'll be compiling _source code_ into _executable files_ or _binaries_ using
our compiler, and then running those binaries directly in our OS terminal.

\* Large language models do not count - these have more to do with statistics
than programming and essentially work by blending together the entire contents
of the internet to guess what a likely human response would be. This is not
"instructing a computer" no matter how many billions of venture capital dollars
are poured into it. I strongly recommend against using any LLM-based tools
anywhere in your programming process.

\** Notably, many interpreted languages these days are _just-in-time compiled_,
where some or all of the program is translated into machine code when the
program starts or while it is running. This helps improve performance but is
basically indistinguishable from the outside compared to interpretation.

## Chapter 1: Writing Code

### Our First Program

That's enough talking - let's start writing code. A common first program is
Hello World - a program that just prints the phrase "Hello, world!" to the
output and then exits. In C, that looks like this:

```c
// file hello.c
#include <stdio.h>

int main(int argc, char** argv) {
    printf("Hello, world!");
}
```

We can compile this program from the command line as follows:

```
bry@computer> cc hello.c
```

If all goes well, this will appear to do nothing, in line with the old-school
Unix philosophy of printing only errors and doing nothing on success. However,
if we use `ls` to list the files in our current folder, we can see our binary:

```
bry@computer> ls
hello.c
a.out
```

It's been named `a.out` for archaic compatibility reasons, which will only serve
to confuse us. We can delete this annoyance with `rm` and fix it by using the
`-o` option in our compiler:

```
bry@computer> rm a.out
bry@computer> cc hello.c -o hello
bry@computer> ls
hello.c
hello
```

We can then run our program, adding `./` to the file path to clarify we want to
run a program from our local directory:

```
bry@computer> ./hello
Hello, world!bry@computer> 
```

Well, that _almost_ worked. We got our printout, but our terminal prompt got
weirdly stuck on top of it. This is because C, even as programming languages go,
takes things _very_ literally. It asked the computer to print "Hello, world!",
and then the operating system asked the computer to print out our terminal
prompt immediately afterward, but nothing in between told the computer to start
a new line of text. We can fix this by adding a new-line character to our print
statement - since this is a directive for the terminal rather than a visible
character, we can't type it directly, but we can use a special sequence called
an _escape sequence_ to represent it in human-readable form:

```c
// file hello.c
#include <stdio.h>

int main(int argc, char** argv) {
    printf("Hello, world!\n");
}
```

C defines a bunch of escape sequences of varying usefulness, but the ones we'll
use the most are `\n` for newline, `\t` for tab, and `\0` for null (we'll
discuss what this means later). There are also escape sequences for characters
that are typeable but would make the string difficult to understand in some
way - `\"` for a literal double quote rather than the end of a string and `\\`
for a literal backslash rather than the start of another escape sequence, plus a
few others. Let's try it with the `\n` added:

```
bry@computer> cc hello.c -o hello
bry@computer> ./hello
Hello, world!
bry@computer> 
```

Much better.

Now that our program is doing what we want, let's walk through it line-by-line.

```c
// file hello.c
```

First we have a comment. Any text on a line after `//` is ignored, as well as
any text between a pair of `/*` and `*/` across any number of lines. This is
great for including human-language notes about what our code is doing or 
temporarily removing code that isn't working yet; here I've used it to show you
what the file is called so the command-line portion makes more sense.

```c
#include <stdio.h>
```

The first thing we do is to include a library. The `<>` brackets here tell the
compiler that this is a built-in system library rather than one that's part of
our project, and the library we're including is `stdio.h`, read "standard I/O".
As the "standard" name implies, this is part of the C Standard Library that is
included with every compiler, and handles input and output operations such as
printing, user input, and file management.

```c
int main(int argc, char** argv) {
```

This is where the real fun starts happening. All code in C is organized into
_functions_, pieces of code that take various inputs and give some output. This
line is read as "Create a function called `main`, which takes as input an `int`
called `argc` and a `char**` called `argv`, and returns an `int` as a result.

In C, the function called `main` is special, and will always run when the
program starts. It always has the "shape" or _signature_ shown here, with `argc`
and `argv` being the **c**ount and **v**alue of command-line **arg**uments given
by the user. For now, we just ignore those; we'll discuss using them in a later
program.

Additionally, you'll notice our line ends with a `{` bracket. This signals the
start of a block of code - in this case, the body of our `main` function.

```c
    printf("Hello, world!\n");
```

As you may be able to guess, this function is what prints to the terminal. Its
name stands for **print** with **f**ormat, but we're ignoring its formatting
features here and just using it to print regular old text. The double quotes
`"..."` indicate to the compiler that `Hello, world!\n` should be read literally
as a text string rather than as a piece of code. The formatting part of
print-with-format can add all sorts of things to our printout based on special
character sequences in our string, but for now we're just using it as a plain
old print.

Note the structure of this line - you'll be seeing a lot of this as we go
forward, so it's good to understand it now:

```c
printf  // function name
    ( // start of parameters
    "Hello, world!\n" // parameter
    ) // end of parameters
    ; // end of statement
```

Also note that we've tabbed in the line by one unit - in my editor this defaults
to four spaces. This helps us remember that we're inside the `{}` of the
function body. Whitespace is usually irrelevant in C, but it's good to get into
the habit of tabbing your code accurately so your code stays readable as it gets
more complex.

```c
}
```

Finally, `}` indicates the end of the function body, corresponding to the `{`
from a few lines earlier. Now that the function is ending, we stop tabbing in to
visually distinguish the end point.

## Chapter 2: Memory and Pointers