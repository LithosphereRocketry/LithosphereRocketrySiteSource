# ATTiny Snake Game

I recently (by some definition, given how good I am about writing things up on
time) attended a holiday party with a handful of my coworkers, which included a
Yankee swap. (White elephant swap? There are many regional names.) If you're
unfamiliar, this is a game where each person donates a gift to a pool. Then, in
a random order, each person gets to choose whether to open a new gift or steal
a previously opened gift, with the person whose gift is stolen then taking
another turn to open or steal.

Never one to turn down an opportunity for a project, I decided to make a gadget
of some kind for my contribution to the swap. So what to build? I considered the
following factors:

* I have a couple of ATTiny85 microcontrollers lying around. Hobbyists seem to
  love low-level AVR programming, which I've never tried, so I should use one of
  these for that.
* I've been meaning to use a charlieplexed LED matrix for something. So the
  gadget should use some kind of matrix display.
* I have only a week or two before the party, so all the parts need to be either
  things I have in my stash or things I can buy locally. Luckily I have an
  excellent local electronics store, so this is a fairly loose restriction, but
  it rules out PCB manufacturing and most surface mount parts.

Eventually I settled on the classic game Snake, known since antiquity and famous
for its inclusion on Nokia phones. This works OK on tiny resolutions and doesn't
require much computing power, while still being interesting enough to hold
someone's attention for a few minutes.

## Charlieplexing

The first problem to consider was the display. This would consume most of the
processing and IO resources of the project, so I figured it was probably a good
idea to make sure it was behaving before getting too far.

First, an overview of charlieplexing. Charlieplexing is a technique to turn very
few I/O pins into a lot of LED outputs, by assigning each pair of pins to an LED
in each direction. Then, each LED is strobed individually in sequence by driving
one pair of pins high and low, and leaving the rest floating. This allows
n*(n-1) LEDs to be driven from n pins, as long as you're OK with reduced
brightness since the LEDs are each only active a fraction of the time. But
modern LEDs are quite efficient and bright, so this shouldn't be a problem most
of the time. More on that later.

I used the "twistyplexing" layout for the display, which I learned about from
mitxela's incredible [fluid simulation pendant](https://mitxela.com/projects/fluid-pendant).
This helps reduce the number of crossings required to wire the matrix, which
tends to make wiring easier both on PCBs and perfboards. On the ATTiny85, I have
6 total I/O pins if I disable the reset pin, so my matrix will have 30 LEDs; I
threw together a breadboard test to make sure this would be feasible:

![A breadboard containing a 5x6 matrix of LEDs and 4 buttons](media/snakegame/breadboard-matrix.jpg)

This is actually not the original breadboarded setup - I made a proof-of-concept
version with random LEDs I had lying around before buying a big pack of red LEDs
for the final product. That worked well, and I was ready to move on to the next
challenge.

## Input

A snake game isn't too useful without input. However, we've already used all six
available pins, so things are going to get a little tricky.

Typically, you'd read button input by weakly pulling a pin high and having the
button short it to ground. However, the only pins we have are shared with a
charlieplexed array, which requires that its pins be able to float when not
being strobed; someone holding down a button would cause a bunch of LEDs to be
lit, and we'd like to avoid that; at worst, the pin being driven high while the
button is holding it low could damage the microcontroller.

One possible solution is to put a small resistor in series with the button, not
large enough to be overwhelmed by the pull-up but enough that the current
passing through it won't visibly light the LEDs. I planned on using the
microcontroller's internal pullup resistors to save components, which have a
minimum value of 20k, and the threshold for a logic low is about 1/3 of the
supply voltage, so that puts the maximum series resistor value at 10k:

![A switch connected to a voltage divider of 20k and 10k](site/media/snakegame/switch_smallseries.png)

Unfortunately in my testing a 10k LED resistor was still fairly visible, at
least with the assorted LEDs I originally tested with. So how do we deal with
this? We could increase the pullup resistance with an external resistor, but
that takes extra parts. However, there's another option...

We don't necessarily need to be bound by the constraints of digital logic
levels. The ATTiny comes with a 10-bit ADC that can be routed to four of its
six I/O pins. We can't rely on a perfect reading, but we should be able to get
within, say, 5 or 10 percent of the correct value reliably. I think I ended up
with a 220k series resistor, which seemed to be reliable at about 11 times the
resistance of the internal pullup. (Interestingly, the internal pullup on the
RESET pin is marginally stronger and required a different ADC threshold.)



