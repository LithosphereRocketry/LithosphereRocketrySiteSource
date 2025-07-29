# MOLLUSC

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



Before attempting any optimizations:

```
ERROR: Max frequency for clock                  '$glbnet$clk48$TRELLIS_IO_IN': 27.30 MHz (FAIL at 48.00 MHz)
```

Oh. Hmmm.

It turns out the way I was doing instruction predication was not very smart.
My original design had a process like:

* Read in an instruction.
* Check its predicate.
* If the predicate is true, pass it through unchanged. Otherwise, pass through
  all zeroes (a canonical `nop`).
* Decode the resulting instruction.
* Check if there are any stall or discard conditions applied to the instruction.
* If so, emit a `nop`. Otherwise emit the instruction normally.

You may notice that there are two different places that I can emit a 
no-operation instead of the normal instruction here. This is not really ideal,
since I can't count on those to be optimized into one operation; the pre-decode
no-op is also a problem of its own for optimization, since it's fully specified
as 0x00000000, meaning that it has to go through the whole decoding process with
no shortcuts. On the other hand, stalls can leave most of their bits unknown, as
long as they give enough information to ensure they won't have any side effects.
To make the most of this, I can just add predicate-fail as another reason to
discard an instruction, which gives me a hefty improvement:

```
ERROR: Max frequency for clock                  '$glbnet$clk48$TRELLIS_IO_IN': 35.77 MHz (FAIL at 48.00 MHz)
```

Well, it isn't quite as good as I was hoping, but it's a good chunk better. A
huge improvement is almost more concerning here than a moderate bump; when that
happens, usually it means some important part of the logic has just accidentally
become undefined, and while the processor will clock very fast in that state it
won't actually run anything.