# NANDy, part 2

Some time ago I embarked on the NANDy project, whose goal was to produce a
somewhat useful CPU from only NAND gates. The early parts of the project can be
found [here](nandy-pt1.html).

To make a long story short, the initial design was not very successful, but it
had some good ideas. Now that I'm embarking on a new design, I want to keep a
few things:

* Keep instructions simple. Despite this being a very 8-bit-era CPU, we're in
  sort of a RISC-era set of tradeoffs - memory is cheap and logic is expensive.
  Doing many simple instructions costs ROM space but saves gates.
* Use one flexible status flag. This simplifies encoding for conditionals and
  saves opcode space; most things I would want to do with a traditional many-bit
  status register boil down to a simple "compare; jump" sequence.
* Likewise, use one powerful accumulator. Routing multiple register values to
  the ALU inputs is not cheap, so fixing one input and handling the excess cases
  with a "swap; math; swap" sequence saves a lot of gates and doesn't hugely
  hinder programming.
* Offset-addressed memory accesses are a must-have. With the tradeoffs above,
  loading an address into a register is always going to be a pretty expensive
  process. For common cases like indexing into structures, being able to use one
  register load to index a whole bunch of fields is a must.

However, there are definitely some improvements I want to make:

* This architecture is absolutely starving for pointer registers. In the
  original design, a single 16-bit register pair was serving as the only way to
  address arbitrary memory and also the only way to do math; this meant
  reloading those registers from the stack basically every time you needed to
  do anything. It's OK to waste cycles and bytes in order to save gates, but
  this was so wasteful that it became miserable to use.
* Jumping to subroutines should be less painful. This is related to above - the
  only way to jump to a subroutine was to clobber the pointer pair and then do
  an absolute jump, clobbering it again with the return address. 10-20 cycles
  per function call, depending on how you count the cleanup the called function
  has to do, is not great.
* I shouldn't be spending a ton of hardware on features that are nice to have
  but not strictly necessary. In the original design, a huge amount of
  complexity (conveniently hidden by the drawings in the original writeup) went
  into making the Y:X pair used for interrupts behave the same as the normal
  Y:X pair and get filled with the interrupt return address on interrupt - the
  PC had to be routed into those registers and then they had to be routed back
  out to Y and X with correct behavior, and when not handling an interrupt those
  two valuable registers were just sitting idle. I did try to make them somewhat
  accessible as general-purpose registers, but they ended up being of very
  limited use, since you could only use them with interrupts disabled due to
  risk of an interrupt clobbering them.
* I need to sort out the interrupt stack. Originally, I could only handle
  interrupts when the stack was valid. This added a "disable interrupts; do
  thing; enable interrupts" wrapper to every single stack operation, which was
  extremely annoying. I later let interrupts have their own stack region, which
  was a start but made interrupt handlers really difficult to write for reasons
  detailed at the end of part 1.
* Finally, I should not be throwing away features that exist in the datapath and
  don't cost hardware outside of their decoding logic. No matter what, this
  architecture is going to be pretty clunky, so I should give all the tools to
  the programmer (also known as "future me") that I can manage.

With those ideas in mind, I decided to start making some more radical changes to
the design to try to get a more usable end product.

## More pointers

The most pressing issue was that I absolutely, no question, needed a second
pointer register. Originally, memory operations took up 6 bits of opcode space
or effectively 64 of my 256 "slots": one bit for read-write, one bit for stack
or Y:X, and four bits of offset. I definitely couldn't get rid of stack
operations and didn't want to reduce the 4-bit offset range, so memory access
had to grow by an extra bit, occupying an entire half of the opcode space. I
decided to call my new pointer registers p and q; p occupies the role of the
previous Y:X pair and is used for function return addresses, while q is
unconstrained and just operates as a general-purpose pointer.

With two encoding bits dedicated to memory mode, I had one more free slot
available for other purposes after allocating stack, p-relative, and q-relative
modes. Applying improvement #5, this became a pre-increment mode, equivalent to
C's `*(++p)` for those familiar with the kind of code annoying C nerds write. I
could already write the active memory address to `p` for return-address purposes
so this cost very little and tremendously sped programs that do a lot of
iterating over memory addresses (spoiler alert, this is most of them).
Originally, this was meant to be a post-increment mode (`*(p++)`) but this was
downgraded to the slightly less useful pre-increment to save one entire 16-bit
multiplexer in the address calculator. (This may not sound significant but it
comes out to about 3% of the CPU, definitely worth a small inconvenience.)

With a tear in our eye we wave goodbye to half of our opcode space and move on
to trying to fit everything into the remaining half. 128 slots remain.

![A spreadsheet showing encoding for two instructions, ld and st.](media/nandy/v7-isa-memory.png)

## More registers

With two pointer pairs we have upgraded our total register count to six (IO bus,
stack pointer, P high, P low, Q high, Q low). We might as well round that out to
a nicely encodeable 8. For this purpose I brought back the X and Y registers,
now used only for math and not as an address pair. With moves and swaps
implemented in the same style as before, this eats 5 bits or 32 slots of space -
move register to accumulator, move accumulator to register, 3 bits of register
selector.

But wait, that's not quite right. Any move instruction with neither move
direction set is effectively a no-op, and 8 slots is an awful lot to throw away
when we're short on space. Are there some instructions from elsewhere we can
fit in here that fit the constraint of taking few or no arguments?

It turns out, yes, there are at least six:

* break to debugger
* enable interrupts
* disable interrupts
* jump to pointer
* jump to pointer and store return
* exit interrupt

It seems like "jump to pointer" would require a 1-bit argument to choose between
P and Q. However, let's consider a few things:

* True jump to pointer is a fairly rare operation - usually, when we use this
  instruction, we're either returning from a function or jumping to a fixed
  address that for whatever reason is not compatible with relative jumps.
* The return address register will be fixed by convention anyway, so there's not
  much point supporting putting the return address in either pointer.
* When calling a function with a pointer address, we will almost always want to
  use the register that gets the return address, because we don't care about
  remembering where we jumped to and that address gets clobbered anyway.

Therefore, "jump to pointer" explicitly always targets the P register. This is
a bit against the "don't throw away functionality" philosophy, but for the
reasons above I think it's a good tradeoff.

Another concern is that we've eaten the space previously used for the "set I/O
address" instruction. I think this is fine - we have a lot of registers to spare
now and arithmetic registers are not very heavily used in I/O code. Therefore,
I'll just plug register Y into the I/O address, making it a bit more Z80-ish in
that regard. This has the added bonus that the I/O address is readable by
software, simplifying interrupt handling - it's easy to go retrieve something
from another peripheral and then get back to whatever the main code was doing,
even if it was also doing I/O.

That leaves two more no-operand slots for future tweaks. I tentatively allocated
one as a software interrupt, which is not hugely useful but might be neat as a
debug tool, and left the other blank for now. Unfortunately, these slots aren't
much good for the instructions we still need to fit in. 96 slots remain.

![The same spreadsheet with the addition of register move and miscellaneous instructions discussed above](media/nandy/v7-isa-move.png)

## Using every cycle

Next up are another very important batch of instructions, relative jumps. Unlike
memory accesses, where going down from 4 to 3 bits of immediate would be a major
downgrade, we can afford to lose a bit of relative jump range - going from 12 to
11 bits is not a huge deal, jumps over 1KB in either direction should be fairly
rare. We can use this to make more space for other instructions, or we can do
something more interesting with them...

When I originally designed NANDy, I thought it was not possible to produce a
relative jump that stored a return address. To perform this operation, the CPU
has to perform three 16-bit additions:

* Compute PC+1, to read the second byte of the instruction.
* Compute PC+2, to find the address of the following instruction - this will
  become our return address.
* Compute PC+offset, to jump to the procedure we're calling.

Since I don't want to allow any instruction to take more than 2 cycles, and I
definitely don't want to shell out for a whole extra 16-bit adder, there's no
way to fit all three operations into one instruction. Right?

During the rework, I realized that that isn't entirely true. The process we care
about is function calling and returning, and over _that process_ we need to
perform three additions. But that process does actually contain a total of three
cycles - two on the call and one on the return. So if we can defer one of the
additions to the return step, we can make it work. And in fact this isn't too
hard to do. Let's rework our three steps from above:

* Compute PC+1, to read the second byte of the instruction. Also store this
  value in P.
* Compute PC+offset, to jump to the procedure we're calling.
* On return, compute P+1 and jump to that location. This will be equal to PC+2,
  making the combined sequence equivalent to the sequence above.

Of course, this comes with some oddities. It doesn't make sense to distinguish
between register-absolute jumps that are returns and ones that are not, so all
register-absolute jumps will have to become register-absolute-plus-one. This is
slightly more annoying from a programmer's perspective but realistically doesn't
matter much - any computed address for a jump table or similar is going to be
added to a base address already, so adjusting the base address by one shouldn't
be a hardship. And in the rare cases where that isn't an option, subtracting one
from P is not particularly difficult.

With this addition, we have four combinations of relative jumps - with or
without conditionals, and with or without return address. With three bits of
the jump offset in the instruction, that uses a 5-bit segment, or 32 slots. 64
slots remain.

![The same spreadsheet with the addition of relative jump instructions](media/nandy/v7-isa-jumps.png)

## What's left

The remaining slots go to our last category of instructions, ALU operations.
There are a number of variations any given ALU operation can take:

* Use immediate or register
* Use x or y register
* Write or don't write carry
* Do or don't carry in

If we add all of these options to every ALU operation, our 64 remaining opcode
slots let us have... 4 operations. Clearly that won't be enough. Luckily we have
lots of options to improve this situation.

One obvious optimization is that an operation that uses an immediate obviously
doesn't need to care whether we use the x or y register, because it uses
neither. I actually didn't end up bothering to use this optimization because
it's a bit awkward - I generally won't need to have an operation that has just
an immediate form and no register form, and it would be awkward to rearrange the
opcodes of instructions depending on whether they were taking an immediate or
not.

Another optimization is that we don't _really_ need carry-in and carry-out to be
separate options. If we're expecting an operation to carry out, the carry flag
will always be clobbered anyway, so we can just set the carry to the default
value (1 for subtraction, 0 for almost everything else.) Of course this costs
a byte and a clock cycle for every multi-byte addition, but those are pretty
slow to begin with so I don't think this will be a huge deal.

Additionally, lots of instructions don't have a meaningful carry-in/carry-out
option: logical operations won't ever need the carry bit, and comparison
operations will always need it. So we can reuse the carry-or-not option to
distinguish between those opcodes.

On top of that, there's a lot of operations that don't make sense in immediate
form. Shifts are always on the accumulator by 1 bit, so those take no second
argument; likewise, to keep things simple, comparisons are one-operand, only
checking whether the accumulator is negative or zero. So there's even more space
open for immediate operations with no register equivalent, which I still don't
need and won't use.

One area where the original design was very wasteful was in shift operations.
Each shift direction offered four different carry-in options - shift in 0, shift
in carry, rotate in the bit from the other end, and extend the adjacent bit.
Most of these were never used and could easily be replicated with a couple of
instructions. So we can cut things down to just shift and shift with carry, and
make the rest the programmer's problem.

While reusing the extra space in the x/y field wasn't useful for immediate
instructions, it's still not a bad idea in general. In particular, comparison
operations won't ever use the x/y field either, and those can actually benefit
from an extra bit - it gets repurposed as an invert switch. So we save a cycle
on about 50% of comparisons by always getting the polarity of result we want,
and as a nice side effect "set carry" and "clear carry" can be implemented with
a single comparison slot.

Let's put this together and see what we come up with:

* Arithmetic: `add x/y/imm`, `adc x/y/imm`, `sub x/y/imm`, `sbc x/y/imm`
* Shifts: `sl`, `sr`, `slc`, `src`
* Logic: `and x/y/imm`, `or x/y/imm`, `xor x/y/imm`, `rdi imm`[^1]
* Comparison: `zero`/`nzero`, `sgn`/`nsgn`, `cset`/`cclr`, `nop`[^2]/`ctog`

[^1]: I didn't mention it in my discussion of ALU operations but despite the
name this is also an ALU logical operation. I need a way to get an immediate
value into the accumulator quickly and easily, and logical operations are the
right shape to make this work - internally, there's an ALU mode that's just 
"output = input B" to make this work. There's some special-case logic to reuse
the register form of this instruction as the `ipoll` operation described in the
previous part.

[^2]: In the first part I said that `nop` was a register move that neither moved
to or from the accumulator, but you may recall we filled up that space with the
small oddball instructions. Luckily, thanks to the invert flag, we get a `nop`
back for free - `nop` is implemented as "read carry, don't toggle it, write back
to carry," the opposite of `ctog`.

With all the tricks we've discussed this assortment of operations can
comfortably fit in our last 64 slots with space to spare. The yellow x's in the
diagram represent bits that don't encode anything - in theory, this would allow
us to add even more operations but realistically I don't think we need any more.
Instead, we can save a few gates by not including them in the decoding logic.

![The same spreadsheet with the addition of arithmetic instructions](media/nandy/v7-isa-all.png)

And there we go. A nice, simple, cozy ISA for a new and improved NANDy
architecture.

## The results

All this rework isn't worth much if it didn't make programs easier to write, so
let's take a look at our `memcpy` benchmark from earlier. As a reminder, this
was the previous implementation:

```
# 60 cycles per iteration
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

With the new architecture, a similarly basic implementation looks like this:

```
# 24 cycles per iteration!
memcpy:
    # get critical data out of the way
    isp -3
    st sp 2
    rd ph
    st sp 1
    rd pl
    st sp 0

    cset
    # retrieve our source address off the stack and decrement it
    ld sp 3
    sbci 1
    wr pl
    ld sp 4
    sbci 0
    wr ph

memcpy_loop:
    # with the P register, we can use the built-in preincrement and suffer a
    # lot less
    ld +p 1         # 2 cycles
    # no such luck with q
    st q 0          # 2 cycles
    cclr            # 1 cycle
    rd ql           # 1 cycle
    adci 1          # 2 cycles
    wr ql           # 1 cycle
    rd qh           # 1 cycle
    adci 0          # 2 cycles
    wr qh           # 1 cycle
memcpy_entry:
    cset            # 1 cycle
    rd x            # 1 cycle
    sbci 1          # 2 cycles
    wr x            # 1 cycle
    rd y            # 1 cycle
    sbci 0          # 2 cycles
    wr y            # 1 cycle
    jc memcpy_loop  # 2 cycles

    ld sp 1
    wr ph
    ld sp 0
    wr pl
    ld sp 2
    jp
```

More than twice the speed, not bad at all! It's far from perfect - we only have
one pointer with an auto-increment mode, so all the others still have to be
handled manually (and no, copying them into P and back is not faster), but
nothing is spilled to the stack and we're much closer to a reasonable speed.
Good enough for me!

Unfortunately this isn't much good without software to run on it. I'll need to
build just about everything from scratch, which will probably take up quite a
few posts on its own. And of course the hardware will be a whole other kettle
of fish on its own.

To be continued...
