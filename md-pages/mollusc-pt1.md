# MOLLUSC part 1: Designing an ISA

Because I didn't have enough homebrew computing projects already with NANDy, I
decided I might as well start another one. A while ago, I took a class on 
operating systems, where the final project was to add a feature to the
[XV6 kernel](https://github.com/mit-pdos/xv6-riscv), a minimal command-line Unix
designed to be tinkered with. Unfortunately, due to my overpacked schedule and
poor relationship with sleep at the time, I didn't really absorb that much of
the material. Now, I've decided to revisit it, in my own particular, uhhh...

!["Idiom, sir?" scene from Monty Python and the Holy Grail](media/mollusc/idiomsir.jpg)

> Idiom, sir?

Idiom.

This means that I'm doing everything basically from scratch, in as stubborn a
way as possible, making most of my decisions based on what I think would be fun
rather than any particular good design practice.

> This is the first post in a series on CPU and OS development, where I'll try
> to go as in-depth as possible on all parts of the process. This won't quite be
> a tutorial, but it'll be a "development story" that you can follow along with
> if you like.

## Goals

This page is not about the operating system itself. Instead, this is about the
CPU that will run this operating system. Because, of course, I couldn't just get
one of the [nice, free, easy-to-use CPU designs](https://riscv.org/) that
already have solid toolchains and just write an OS for it. That would be boring.

This architecture needs to do a couple of things:

* **Be relatively easy to understand.** If I, the one making the architecture,
  don't know what's going on, the whole project basically falls apart.
* **Be nice to write assembly code for.** My [other CPU project](nandy.html)
  has convinced me that general-purpose registers, big memory spaces, and
  especially non-tiny stack space are basic necessities when creating something
  I actually want to use for complex tasks.
* Related, **be nice to write compilers for.** While smaller projects are fine
  for assembly, writing a whole memory-managed OS is going to be a lot easier
  if I can do the bulk of the work in C. Unusual, cramped, or otherwise weird
  architectures tend to be torturous to compile for, and I am not a compiler
  expert, so keeping it "normal" is going to be the name of the game here.
* **Interface with common components.** Even as much as I love writing things
  from scratch, there is going to be a point where I get really, really sick of
  designing interface logic.

## What is an architecture?

In building a CPU architecture, the first step is generally to pick out an
**ISA**, or instruction set architecture. An ISA is the specification that
defines how the bytes of machine code being fed into a computer are translated
into actions the computer will perform. ISAs are generally what are being talked
about when people say "architecture"; you may have heard of some of the popular
ones, like x86 (almost every computer that runs Windows) and ARM (phones and
newer Macs). In general, binaries written for a given ISA should run on all
processors of that ISA, albeit not necessarily well or fast.*

One important distinction that spawns many forum arguments is the distinction
between complex-instruction-set computer (CISC) and reduced-instruction-set
computer (RISC) architectures. This is a very fuzzy line, but the general
characteristics are:

RISC:

* Fixed instruction size
* Fixed alignment (e.g. you'll never ask for 4 bytes starting from address 3)
* Memory accesses are distinct operations (i.e., to increment a value in memory,
  you do "load, increment, store")

CISC:

* Variable instruction size
* Variable alignment (ask for any memory you want, it'll figure it out)
* Memory operations happen as part of other operations (increment in memory is
  a single instruction)

There are a lot of debates about which architectures are in which category, not
to mention the truly exhausting amount of arguments over which is "better", so
I'll leave it at this for now: my architecture will be completely and
indisputably RISC, because simpler instructions means less hardware and less
work for me. 

> \* ISAs aren't always quite this simple, as we'll get into in a moment.

### What else is an architecture?

The other side of the architecture coin is **microarchitecture**. 
Microarchitecture is the "how" to ISA's "what" - the way that the ISA is
actually implemented, in terms of logic gates and registers. With the huge
modern tech market demanding easy cross-compatibility between devices, most
architecture research these days is in microarchitecture: how to run the same
x86 code in fewer cycles or a faster clock speed or less power, rather than
starting from scratch.

In my NANDy writeup, I largely merged both aspects of architecture because
that's how I developed them; that processor was so limited on hardware that
the ISA had to evolve hand-in-hand with the microarchitecture, with the encoding
of instructions closely matching the actual configuration of the hardware. Here,
I'm aiming for readability and expandability, so it makes sense to separate the
two to some extent.

We're getting ahead of ourselves a little here, though - this post is just about
the ISA.

### OK, but wait, what else is an architecture?

OK, I admit, I've skipped an important part of architecture here - ISA 
_extensions_. (This is what that asterisk above was about.) An ISA extension
is what it sounds like; it adds optional features to an ISA which some but not
all processors support. x86, as it exists today, has been built as sort of a
Ship of Theseus of ISA extensions; most architectures that have been around for
some time have at least a few.

With some ISA extensions, it's possible to make a system binary-compatible with
the extension, even if the system has no dedicated hardware implementing that
extension. For example, if an extension adds support for floating-point numbers,
a processor without floating-point hardware might decide to throw an "illegal
operation" exception whenever a floating-point instruction is used. Then, an
operating system can catch that exception and emulate the failed instruction in
software, handing the result back to user code as if no error had happened,
albeit much slower. However, it's not reasonable to do this for every extension:
another common extension is virtual memory, which we'll discuss later but
essentially involves dynamically remapping memory to isolate each program to
a "clean" memory space. Clearly, this requires some amount of actual hardware
to support.

## Get to the point already

Alright, enough about terminology, let's get to what I'm actually making. A good
way to design an ISA is to think through simple use cases and consider how you
want that use case to be implemented.

It's also good to set some general ground rules for your architecture, such as
bit widths and instruction-size variability. ISAs may have native data sizes
anywhere from 8 bits (e.g. 6502) to multiple 64-bit words at a time (x86 with
extensions); instructions may be very predictable in size (RISC-V) or
arbitrary down to the bit level (i432, ugh). In my case, I'll be using a 32-bit
data width and a fixed 32-bit instruction size, comparable to older variants of
most RISC architectures such as RISC-V, ARM, MIPS, and PowerPC. I'll also be
using 16 registers, of which one is always zero.

### Branching and predication

One of the most important operations for a CPU to perform is branching. A branch
is where the CPU makes a decision about what to execute based on some piece of
data it has. Here's an example in RISC-V:

```asm
    addi t0, x0, 5                ; load 5 into t0
    bgt a0, t0, greater_than_5    ; branch if a0 > t0
    ...                           ; a0 <= 5 here
greater_than_5:
    ...                           ; both paths converge here
```

There are a few ways to implement branching in an ISA. RISC-V here demonstrates
one popular option: include a comparison in the branch instruction itself. The
challenge with this is that storing the names of those several registers
consumes a lot of bits in the binary form of the instruction. This reduces the
number of bits available to the address part of the operation, reducing the
possible jump range.

Older architectures, such as x86, often use status flags instead:

```asm
    cmp eax, 5         ; Compare and store result in status flags
    jg greater_than_5  ; If status flags indicate comparison was greater, jump
```

This makes the jump operation nice and compact, but carries the disadvantage
that there's a hidden dependency between those two instructions. If we do almost
any math operation between the comparison and the jump, the status register will
be messed up and we'll get the wrong result. As a programmer, this isn't a big
deal - just compare right before you jump - but it becomes an issue in more
complex microarchitectures where there may be many instructions in flight at a
given time; the CPU must then keep track of all of those hidden dependencies to
make sure nothing happens with the wrong data.

A middle-ground option is to make branches decided by a single register, simply
checking if it's zero or nonzero, and using math operations to perform
comparison ahead of time:

```
    gt r1, r0, 5
    br r1, greater_than_5
```

This helps to soften the blow of the redundant bit usage of option 1 while not
carrying the hidden dependencies of option 2. However, it has the issue that
we have to consume an entire register for, effectively, only one bit of data.
Register space is valuable because it's the fastest storage in the processor;
not only does using more registers force data to be spilled to slower RAM, but
adding congestion to the register file logic to support reading to more
locations makes the processor bulkier in hardware and thus slower.

As a compromise, I decided on a variation of this strategy: branching is still
done by storing the result of a comparison to a register, but the registers used
for branching are distinct from those used for regular numbers; this makes them
much cheaper as they use only 1 bit in hardware rather than the usual 32, and
means that they don't displace regular data.

#### Taking it a step further

A common ISA extension is to support predicated execution - regular
instructions, rather than branches, which may or may not execute depending on
a condition. For this architecture, I decided to make all instructions
predicated by default. There are no unique branch instructions; a branch is just
a jump with a predicate. Since I don't want to deal with sequences of
instructions with hidden dependencies, this is done by reserving the highest 4
bits of the 32-bit instruction to select one of 8 predicate registers and
possibly invert its value:

```
Bits  31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
      ^P [  Rp  ]
```

This structure is common to all MOLLUSC instructions, which makes it very simple
to decode but does take away four whole bits from the rest of the instruction
forever. Is this a worthwhile tradeoff? Probably not! But it's my architecture
and I'll do what I want.

### Loading constants

Another key question is how constants should be loaded into registers. On x86,
this isn't a problem; because instructions can be arbitrarily long, loading a
32-bit value is just an 8-bit opcode followed by a 32-bit immediate. However,
my instructions are always the same size as my data, so that obviously won't
work. The alternative, which most RISC architectures implement, is to load
a constant value by halves in two consecutive instructions. ARM splits its
registers exactly in half for this, while RISC-V splits them unevenly; I'll be
using the RISC-V style, so that I can reuse the format of the smaller half for
normal constant-addition instructions and the like:

```
lui a0, 0x12345000 ; load most of the value...
add a0, a0, 0x678  ; top it off with the last bit
```

The obvious next question, then, is how I want to split the two parts of the
constant. I decided that, to conserve bits in the "normal" operations, I want to
cram as many bits into the longer part as I can, while still reusing the
long-constant format for a few other instructions. In particular, I need long
immediates for these three operations:

```
lui   ; load upper immediate - what was discussed above
auipc ; add upper immediate to program counter - like above, but loads an
      ; address relative to the current instruction; useful for grabbing data
      ; from elsewhere in the binary without having to worry about where we're
      ; physically placed in memory (more on this in a later article)
j     ; jump, forward or backward by a fixed amount from the current PC
```

All of these instructions have the ever-present predicate, a destination (a
return address for jumps), a long immediate, and nothing else. To maximize the
size of the immediate, I encode these with a 2-bit opcode, where opcode `00`
means "everything else":

```
Bits  31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
      ^P [  Rp  ]              0  0 
j     ^P [  Rp  ] [   Rd    ]  0  1 [                           Immediate                           ]
lui   ^P [  Rp  ] [   Rd    ]  1  0 [                           Immediate                           ]
auipc ^P [  Rp  ] [   Rd    ]  1  1 [                           Immediate                           ]
```

(Note that I'm always aligning register addresses to groups of 4 bits. This
makes hex dumps of the code much easier to read, as register numbers will always
land on their own hex digit.)

