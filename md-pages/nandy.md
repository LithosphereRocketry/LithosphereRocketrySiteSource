# NANDy

Some time ago, I was idly playing around with digital logic and remembered
something that seemed to be part of every piece of computer-engineering
educational material: you can make any logical device out of NAND gates.
(As an aside, NOR gates can do the same thing; I don't know why they don't get
talked about as much. Heck, a computer made entirely out of NOR gates landed us
on the moon.)

I decided to take a look at what it would take to implement an entire basic CPU
using only standard off-the-shelf NAND gates. It turns out, this is a very bad
idea.

Before we get too far into the weeds, I set some general ground rules and goals
for this project:

* The CPU itself will be entirely NAND gates. That's kind of the whole point
  of the project.
* Any part which is strictly a NAND gate is permitted. This includes gates with
  any number of input pins as well as open-collector and other gate types.
  Schmitt-trigger gates are an interesting gray area, since they technically
  contain memory elements and therefore could be considered not just gates, but
  I don't plan to use any anyway, so it doesn't really matter.
* Parts that are not the CPU are not restricted to NAND gates. I briefly
  considered building RAM and ROM out of gates, but it gets extremely tedious
  extremely quickly for any useful amount of storage. Additionally, clock
  generators and other support components can be built however I like. However,
  I won't push this limit; integrated memory chips will be used only for things
  that are fundamentally memory, and not dubious cases like microcode ROMs.
* Peripheral devices don't have to be NAND gates, but it's more fun if they are.
  My general game plan is to implement these parts on an FPGA and then transfer
  them to dedicated ICs if they're simple enough.

## Basics

Our building block for the project, for the most part, is going to be this:

![Integrated circuit marked with code 74AC00P](media/nandy/7400.jpg)

This is about the most standard NAND gate you can get. It's a 4-module, 2-input
CMOS gate compatible with 5V logic levels; the AC in the part number indicates
that it's fairly fast, and most importantly it is very inexpensive in decent
quantities.

As the theorem states, we can build any combinational logic we want out of
these. Here's an XOR gate and a 1-bit full adder:

![Schematic of XOR gate and full adder implemented using NAND gates, with
equivalent symbols alongside them](media/nandy/combinational.png)

Building elements that have memory is a bit trickier, and a bit less elegant.
Because memory elements tend to depend on themselves, they don't lend themselves
well to concise mathematical representations, instead relying on timing and
implementation details. Latches - components that allow their contents to change
continuously whenever their clock signal is high - aren't too bad:

![Schematic of D latch implemented using NAND gates](media/nandy/dlatch.png)

Flip-flops - elements that can instantaneously sample a signal on the rising or
falling edge of the clock - are a bit more difficult. While it's possible to
build a functioning CPU without these components, it's a bit more difficult;
generally, it requires a two-phase clock or other similar strategy. 

Wikipedia gives an example of a D flip-flop that looks like this:

![A D flip flop design made from 6 NAND gates, structured as 3 RS latches](media/nandy/dff_wikipedia.png)

*By Nolanjshettle at English Wikipedia, CC BY-SA 3.0, https://commons.wikimedia.org/w/index.php?curid=40852354*

This design works great - and I originally planned to use it, and even got as
far as prototyping some components using it - but it's not actually that useful
for my purposes. The main issue is that it doesn't have a write-enable input, so
retaining a value for more than one clock cycle requires either multiplexing the
output back into the input or doing a significant amount of tearing-apart of the
internal logic, either of which adds a lot of component cost. Instead, I went
with a design that looks like this:

![A D flip flop design made from 9 NAND gates, structured as a pulse generator and D latch](media/nandy/dff_mine.png)

This is, to be brutally honest, a fairly ugly solution. You may notice that it's
just a D latch as above, but with a weird piece of combinational logic for the
write signal; this logic computes the expression (CLK and not (not (not CLK))),
which is almost always 0. When clock gate switches high, it takes about 30
nanoseconds for the signal to propagate through all of those inverters, so as
long as the input doesn't change for those 30 nanoseconds it'll write correctly.
There's nothing else in the computer that's remotely that fast, so this works
great. An added bonus is that the edge-detector structure can be shared across
all the bits of the same register, so it only has to be implemented once instead
of 8 times; technically, only one edge detector is needed for the whole computer,
but I figured relying on a high-speed pulse like that to stay intact across that
distance was asking for trouble, so one per register it is.

## The Architecture

For the architecture of this CPU, I went through quite a few iterations before
settling on a final design - in my own notes, the current design is referred to
as "architecture 4.5." The design takes a lot of impsiration from the MOS 6502,
with an X and Y index register, accumulator, and 256-byte stack. However,
compared to other 8-bit-era processors, it's a lot more RISC-ish: no indirect
arithmetic operations, only separate loads and stores.

The core specs of the machine currently look something like this:

 * 1 MHz processor clock
 * 32KB ROM, 32KB RAM (256 bytes usable as stack) 
 * 1 hardware interrupt
 * Function calling with reentrancy and recursion (at least until you run out of
   stack)
 * Power consumption: about 10 watts projected (mostly LEDs)

To help ease the pain of having so few registers, there are also a collection of
swap instructions, which instantaneously exchange any register with the
accumulator. Then, instead of the 6502's `inx` to increment X, we do
`sw x; addi 1; sw x`. The main motivation for this increase in code complexity
was to reduce the number of states required for instruction execution; no
instruction takes more than 2 cycles, and a large quantity (basically, anything
that doesn't require extra memory accesses) only requires one.

Originally, the one exception to the "arithmetic only happens on the
accumulator" rule was the increment-stack-pointer operation. This is because the
processor supports interrupts for I/O, and interrupts assume the stack to be in
good working order; to implement `isp` from swaps would have to take up 5
instructions:

```
dint      # Disable interrupts
sw sp
addi -3
sw sp
eint      # Enable interrupts
```

That's not even to mention that you might want to increment the stack pointer
when interrupts were already disabled, so it can't even be made into a nice
handy macro. At this point in the project, I didn't really think this was worth
the component-count benefit, so `isp` stayed in as an oddball.

One place I did accept a bit of clunkiness to reduce the instruction set was in
procedure calls. NANDy supports relative jumps - i.e. "go to 327 bytes after the
current instruction" - both with and without boolean conditions, but procedure
calls - i.e. "go to this location, and store my previous location for future
use" - must be done by loading the X and Y registers with an exact address:

```
wr dy    # Stash current accumulator value in Y register
rdi 0x12 # Load lower byte of function address
wr dx    # Put it in lower index register
rdi 0x34 # Load upper byte of function address
sw dy    # Put it in upper index register, and at the same time get our original
         # accumulator value back
jar      # Jump to function
```

Luckily, since this is all register-juggling and doesn't use the stack, it can
be neatly wrapped up in a macro:

```
call func
```

## Picking a Goal

As the feature creep started to build up on this project, I realized I really
needed to settle on a goal to keep this from dragging on forever. Originally, I
had planned on trying to make it play Tetris, but I eventually decided against
that, mostly for interfacing reasons - either I'd need a full-featured graphical
output, which would be expensive and complicated, or I'd need to build a 
specific made-for-purpose Tetris board display, which wouldn't be very
interesting. I also considered a couple other options:

* IRC client via old-school serial modem - requires learning a lot of different
  protocols, and networking things never work
* Scientific calculator - requires floating-point and/or high-precision math
* Lisp interpreter - this one is pretty plausible; the only limitation is that
  deep recursion requires some extra thought when you only have 256 bytes of
  stack
* Full-fledged DOS-style prompt - this would be a lot of fun, but also a *lot*
  of added scope

In the end, the thing that convinced me was someone recommending that I try the
classic text adventure Planetfall. Planetfall and the other Infocom games are
especially interesting in that they may be the first games written using an
engine and virtual machine, rather than direcly to assembly. Infocom games were
written in a human-readable, Lisp-like language called ZIL, then compiled to a
virtual-machine bytecode called Z-Machine. This means that any computer that can
interpret Z-Machine bytecode can in theory run any Infocom game. Being a text
adventure, I/O can just be a serial port, and the command set was simple enough
to implement on 8-bit computers of the time like the Atari 800 and Commodore 64.
Perfect for my minimal CPU!

## The Datapath

After a large amount of iteration and rearranging, I ended up with a datapath
that looks something like this:

![High-level diagram of processor datapath](media/nandy/datapath.png)

This is somehow simultaneously a bit of a rat's nest and restrictively simple.
Let's take a look at how a few relevant instructions pass through the datapath:

The simplest thing that it's possible to do on the processor is a no-operation,
abbreviated `nop`. On a CPU, the task of "doing nothing" typically entails two
steps: loading the nop instruction itself from memory, and incrementing the
program counter to point to the next instruction. In the NANDy datapath, those
steps occur via the green and blue paths here respectively:

![Processor datapath with fetch and PC-increment paths highlighted](media/nandy/datapath-nop.png)

This same fetch-and-advance structure is present in almost all instructions. For
example, adding the X register to the accumulator looks like this, with the
actual operation occurring via the red path:

![Processor datapath with fetch, PC-increment, and arithmetic paths highlighted](media/nandy/datapath-add.png)

By looking at the datapath here, we can see why I was a little salty about not
being able to easily replace the separate `isp` operator with other operations.
There are three whole multiplexers here whose sole job is to implement the `isp`
operation. Yuck. Who knows, I may end up going to the manual solution that I
said was too complex originally after all.

![Processor datapath with increment-stack-pointer path highlighted, with arrows to three multiplexers used](media/nandy/datapath-isp.png)

Most of the register-move instructions are made up of two parts, an incoming
(red) and outgoing (yellow) path, which transfer data to and from the
accumulator respectively. Using both paths at the same time results in a swap,
and one or the other can be used to implement a simple move. (As an aside,
internally, `nop` isn't actually its own instruction - it's just a register
move where neither path is enabled.)

![Processor datapath with register read and write paths highlighted](media/nandy/datapath-sw.png)

The most complex thing we can do on a single cycle is make a function call. To
do this, we have to do a couple things at the same time:

* Read and decode the instruction. (green)
* Combine the X and Y registers into an address, and load that as the next
  program counter. (blue)
* Calculate where the next program counter *would* be, and load that into the
  X and Y registers. (red)

This is where we finally do something interesting with the address calculator:

![Processor datapath with jump to address and store return path highlighted](media/nandy/datapath-jar.png)

I mentioned earlier that the processor doesn't support function calls on
relative jumps; this is because there's only one 16-bit adder in the address
calculator, and a relative function call needs to both add a relative offset to
the program counter for the jump itself and add one to it to calculate the
return address. In theory, this could be done on the same adder on two different
cycles, but I decided that just using absolute jumps would be easier than
dealing with added control complexity. Of course, we can also use this to
implement absolute jumps with no return address simply by turning off the
return-address path.

Beyond this point, we've exhausted everything that's possible in a single cycle
and now have to move on to two-cycle instructions. The NANDy architecture is
designed such that every cycle is some type of memory access, meaning that these
instructions are ones that have to fetch or store something in addition to their
opcode.

The simplest two-cycle instructions are the immediate arithmetic operations:
instructions that take the form `acc <= acc <op> constant`. These - and all
other 2-cycle instructions - look more-or-less like a no-operation on their first
cycle, and only use it to latch the value of the current instruction. This frees
up the memory bus on the second cycle to allow it to provide the constant value:

![Processor with memory-to-arithmetic and PC-increment highlighted; instruction fetch is notably absent](media/nandy/datapath-addi.png)

Note that PC is still incremented as normal. Immediate instructions have their
constant byte immediately following them in memory, so we can just keep on
going as if they were two instructions.

Relative jumps are also implemented this way. 4 bits of the instruction and the
8-bit constant are combined to give a 12-bit offset range, and we can just use
this value in place of incrementing by 1:

![Processor with relative-jump path highlighted; jump is accomplished using same adder that would be used for PC increment](media/nandy/datapath-j.png)

(You may notice that I've skipped conditional jumps here; those are mostly
identical to normal relative jumps, with all the differences handwaved inside
the control logic block.)



## The I/O Dilemma

Here, we pause our regular programming (heh) to discuss the I/O situation a bit.
Originally, I designed the processor around a single 8-bit input-output port.
This made a lot of sense when I first started developing the project; originally
I had planned for the processor to be a lot more primitive, with only one index
register instead of two and only 256 bytes of RAM. However, feature-creep got 
the best of me, and I ended up designing something that might be capable of more
complex tasks, which necessitated more complex I/O.

This left me at a bit of a dilemma: I had already designed the instruction set
to support only a single I/O port, but for most of the end goals I had for this
architecture, I would need more ports. The options I considered were:

1. Keep the I/O design exactly as is, and require every I/O request to contain
   a prefix indicating the device to target and possibly how many bytes to send
   to that device.
2. Keep the I/O design exactly as is, and consider each I/O request to be a
   4-bit address followed by a 4-bit data value, or some other similar split.
3. Add a single-bit chip-select output that is controlled by dedicated
   instructions; when chip-select is active, I/O writes set the device address
   to be used in the next operation.
4. Keep the I/O design mostly as is, but reuse one of the index registers as an
   I/O address register.
5. Ditch the I/O register entirely, and make I/O either part of the memory space
   (*a la* 6502) or its own pseudo-memory space (*a la* Z80).
  
I fairly quickly narrowed down the options to 3, 4, and 5; most of the devices I
want to use take an 8-bit input, and having the external logic to distinguish
prefixes from device data would add a whole lot of complexity that I don't want
to deal with.

## Reconsidering `isp`

Drawing out the datapath diagrams really made me wonder how much I could save by
getting rid of that `isp` instruction, and how much it would really cost me in
terms of performance. I ran a few tests in the emulator and concluded that the
tradeoff was worth it. Although removing it ate 10-20% of the processor's
performance in most of my test programs, this processor isn't really designed
for computational prowess anyway, and the physical hardware cost was starting to
look pretty significant. Without it, the datapath looks like this:

![Same datapath as before, with highlighted multiplexers removed](media/nandy/datapath-no-isp.png)

So not a whole lot different, but a lot of wiring and gates have been removed.
The main advantage that sold me on this is that it offers a new solution to my
other nagging issue, configuring the I/O port. As well as cutting out a lot of
physical complexity, removing `isp` also frees up the operation codes it
consumed. Conveniently, the original `isp` operation code looked like this:

```
Bit:  7 6 5 4 3 2 1 0
      0 0 1 c [ offs ]

c: 1 if carry bit is set, 0 otherwise
offs: 4-bit signed offset to apply to stack pointer
```

This can conveniently be repurposed as an I/O addressing function:

```
Bit:  7 6 5 4 3 2 1 0
      0 0 1 [  addr  ]

addr: Address of I/O device to select
```

The nice thing about this approach is that it's easy to assign a device a range
of addresses; since I now have a consistent 5-bit address space, I can set up
memory maps in much the same way you would on a Z80.

A further challenge that I glossed over in my earlier discussion of I/O is
handling multiple interrupts. I'm likely to have a slew of devices competing for
the processor's attention at any given time, so I need some way to decide which
the CPU will answer first. The traditional way of doing this is with a priority
encoder - a device that takes in a whole bunch of interrupt lines, and outputs
the address of the first one that's active. However, priority encoders require
a pretty substantial number of chips to implement in NAND logic, and are pretty 
overkill for my purposes. I'm pretty unlikely to need more than 8 different
I/O devices, so why not just give the CPU a full list of every active interrupt
and let it choose which to use?

Originally, I wanted to avoid adding any extra instructions, so I decided to
make this list an I/O device of its own, which always resides at address
`0b11111`. Later, I backtracked on this and found a perfect candidate spot for a
"poll interrupts" instruction: the "read immediate" instruction in register mode
was just a weird way to do "read x" or "read y", which are already handled by
the register transfer instructions. Instead, I found a way to integrate a
multiplexer into the mess of hand-optimized logic I was using to implement the
`rdi`, `and`, `or`, and `xor`, allowing the interrupt status to be polled
without messing with the IO address register.

Thanks to the
power of shift instructions, this even makes for a pretty slick
interrupt-handling process:

```
ISR:
  isp -3 # note: this is a macro now, implemented in the clunky way from earlier
  strs 0 # stash the registers so we can restore the state at the end of the ISR
  rd dx
  strs 1
  rd dy
  strs 2

  ipoll

  sl    # Peek at the 0th bit; if it's 1, go to handler 0
  ctog
  jcz handler_0
  sl    # Peek at the 1st bit; if it's 1, go to handler 1
  ctog
  jcz handler_1
  ...

isr_done: # handlers jump to here afterward
  lds 2
  wr dy
  lds 1
  wr dx
  lds 0
  jri # Clean up and exit interrupt
```

This brings up an interesting issue: it's created yet another piece of CPU state
that might be messed up by an interrupt. Consider the following scenario:

* I decide to read some data from permanent storage. I set the address of my
  storage card, and start sending the storage request.
* In the meantime, someone starts typing on the serial port. This sends an
  interrupt to the CPU.
* The CPU jumps to the interrupt and reads some data from the serial port, then
  returns execution to me, with the registers just as I left them.
* Seeing nothing wrong, I start writing my data to storage. Oops! I just sent
  it to the serial port instead.

There's a couple ways around this problem:

* I could just not do anything, and make blocking interrupts mandatory for any
  kind of I/O. This is an annoying thing to do and a performance and binary-size
  hit, but it requires no actual work.
* Interrupts could just force you to look at the interrupt mask, and all I/O
  happens in "normal" code. This means the interrupt controller doesn't have to
  borrow an I/O address, but it's really annoying to work with; it also kinda
  defeats the purpose of having interrupts for a lot of things.
* There could be two different I/O address registers, one for normal code
  and one for interrupts. This would be much easier to work with, but adds a lot
  of hardware, which I'm really trying to avoid.

Given these alternatives, I ended up leaning toward option 1. I'm not too picky
about the performance of this system, and I *should* have enough ROM space to
throw at the issue to avoid any constraints there. 

## Writing some code

At this point, I thought it would be best to start building up a library of
software to get a sense for how the system would be to work with. I started with
a function that would be useful for all sorts of software and should be fairly
straightforward: `memcpy`. And wow, am I glad that I did this before I got
further into the weeds.

A generic `memcpy` pseudocode algorithm looks something like this:

```
loop:
  if count == 0:
    exit
  mem[dst] = mem[src]
  increment dst
  increment src
  decrement count
  goto loop
```

So we have to keep track of three pointer-sized values, and increment or
decrement each of them once per loop. In a normal processor, you'd be able to
keep these all in registers and increment them each in one instruction. This
is... not a normal processor. We have approximately one pointer-sized value of
register space, and it will take a minimum of eight cycles to increment it:

```
  sw x
  addi 1 # 2 cycles
  sw x
  sw y
  addci 0 # 2 cycles
  sw y
```

This means that basically all of our function data has to live on the stack,
loading and writing back one byte at a time. Here's what the full implementation
of memcpy looks like:

```
memcpy:
    _isp -2
    rd dx
    strs 0
    rd dy
    strs 1

memcpy_loop:
    lds 7
    zero
    jcz memcpy_byte
    lds 6
    zero
    jcz memcpy_byte

    # if we fall through, then size is 0 and we exit
    lds 1
    wr dy
    lds 0
    wr dx
    _isp 2
    ja
    
memcpy_byte:
    # decrement size
    lds 6
    subi 1
    strs 6
    lds 7
    subci 0
    strs 7

    # copy byte
    lds 4
    wr x
    lds 5
    wr y
    lda 0
    wr y
    lds 2
    wr x
    lds 3
    sw y
    stra 0

    # increment pointers
    rd x
    addi 1
    strs 2
    rd y
    addci 0
    strs 3
    lds 4
    addi 1
    strs 4
    lds 5
    addci 0
    strs 5
    j memcpy_loop
```

This code was not very pleasant to write, nor is it very pleasant to read. It
works, but almost every useful operation is flanked by a load-from-stack and
store-to-stack pair, taking two cycles each. At around 200 bytes, it's not very
space-efficient, and at around 60 cycles per byte copied it's extremely slow as
well.

It was at this point that I realized that this wasn't really a practical
architecture. Sure, I could make it work, but all of the code I would write
going forward would be at least this ugly, and it just wasn't going to make the
project any fun. Additionally, there were a lot of warts on this so-far simple
architecture that I could really do with getting rid of.



https://www.imdb.com/title/tt0158814/quotes/?item=qt0412749&ref_=ext_shr_lnk