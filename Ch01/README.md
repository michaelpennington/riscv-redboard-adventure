# The Beginning

So you want to learn how to program embedded devices, want to learn more about
how computers work at a fundamental level, etc? Let's take a journey and learn
how to write a blinky program for the sparkfun redv redboard from scratch!

## Prerequisites

### You must have:

- A Sparkfun RedV Redboard
- A computer running linux (other OS's will probably work if tweaked, untested)

### You must install:

- openocd
- gcc riscv64 toolchain

### Required documents:
- [Freedom E310-G002 Manual](https://www.sifive.com/document-file/freedom-e310-g002-manual)

## Getting Started

Let's look at the manual for the sifive fe310 g002. This is the SoC
on the redboard containing the riscv processor, as well as various peripheral
controllers, memory, gpio access, and more. The fe310 features 
*memory-mapped io*, meaning input and output can be acheived via reading from
and writing to certain addresses in memory.

Turning to page 76 of the manual, we see the specification for the gpio
controller. Its address is 0x10012000, and there are 19 different parameters
that can be controlled for 32 individual gpio ports. We're interested in turning
the led on the board on, which in this case is located at **Pin 5**.
Looks like we need to set the output enable bit and clear the input enable bit
to start.

So let's fire up our editor, and write some assembly to do this!

```as
# blinky.s
  lui x1, 0x10012
  addi x2, x0, 0x20
  xori x3, x2, -1

  sw x2, 8(x1)
  sw x3, 4(x1)
```

Let's break this down a bit:

    lui x0, 0x10012

First, we load 0x10012 into the upper 20 bits of the register x0, effectively
setting x0 to 0x1001200 (the address of the gpio port).

Next, we load 0x20 into x2, as 0x20 is 0b00100000, representing the 5th gpio
port (led port). In addition, we invert this by xoring the value with
0xFFFFFFFF, storing it in x3 for help in clearing the bit.

    addi x2, x0, 0x20
    xori x3, x2, -1

Finally, we set the led bit for enable output, and clear the led bit for
enable input:

    sw x2, 8(x1)
    sw x3, 4(x1)

For now, we won't bother doing anything complicated for a delay, and will just
count down from a high number and waste clock cycles. So we start our loop,
and initiate a timed count down.

```as
loop:
  lui x4, 0x600
1:
  addi x4, x4, -1
  bne x4, x0, 1b
```

And finally, we toggle the led bit of the output val register and complete the
loop

```as
  lw x4, 8(x1)
  xor x4, x4, x2
  sw x4, 8(x1)

  j loop
```

Ok, let's try to compile this!

    > riscv64-unknown-elf-gcc -march=rv32imac -mabi=ilp32 ./blinky.s

Uh-oh, we get an error:

    (.text+0x2c): undefined reference to `main'
    collect2: error: ld returned 1 exit status

Ah, we're trying to link to the c library, which requires a function called
main as the entry point. We're trying to go full bare-metal here, so let's
specify -nostdlib to the compiler.

    > riscv64-unknown-elf-gcc -march=rv32imac -mabi=ilp32 -nostdlib ./blinky.s -o blinky

Now we get a warning that we "cannot find entry symbol _start; defaulting to
00010074". Let's define a label at the beginning of the program called _start,
and export it as a global symbol:

```as
.globl _start
_start:
  lui x1, 0x10012
  ...
```

If we dissasemble the resulting object file, we see that our code is there!

```
❯ riscv64-unknown-elf-objdump -d -M numeric,no-aliases blinky

blinky:     file format elf32-littleriscv


Disassembly of section .text:

00010074 <_start>:
   10074:       100120b7                lui     x1,0x10012
   10078:       02000113                addi    x2,x0,32
   1007c:       fff14193                xori    x3,x2,-1
   10080:       0020a423                sw      x2,8(x1) # 10012008 <__global_pointer$+0x10000768>
   10084:       0030a223                sw      x3,4(x1)

00010088 <loop>:
   10088:       00800237                lui     x4,0x600
   1008c:       127d                    c.addi  x4,-1 # 7fffff <__global_pointer$+0x7ee75f>
   1008e:       fe021fe3                bne     x4,x0,1008c <loop+0x4>
   10092:       0080a203                lw      x4,8(x1)
   10096:       00224233                xor     x4,x4,x2
   1009a:       0040a423                sw      x4,8(x1)
   1009e:       b7ed                    c.j     10088 <loop>
```

If we try to flash this code to the redboard, nothing will happen. Taking
a closer look at page 23 of the manual, we see the program entry point is
fixed at address 0x20010000, which is in flash memory of the fe310 g002.
Thus we need to load our program into this address, not 10074 as it is now.
For this we must create a *linker script*. Enter the following into a new
file called "link.ld",

```ld
MEMORY
{
  flash (rx!w) : ORIGIN = 0x20010000, LENGTH = 0x6a120
}
```

and compile it again, using the *-T* argument to include the linker script.

    > riscv64-unknown-elf-gcc -march=rv32imac -mabi=ilp32 -nostdlib -Tlink.ld ./blinky.s -o blinky

We try to flash it and... nothing.

    > openocd -f board/sifive-hifive1-revb.cfg -c "program ./blinky verify reset exit"

Ah-ha, the gpio pins have "alternative functions", which can be enabled or
disabled by writing to the correct gpio iof enable bit. We add a few extra
lines to clear the alternative function pin for pin 5.

```as
  ...
  sw x2, 8(x1)
  sw x3, 4(x1)
  lw x4, 56(x1)
  and x4, x4, x3
  sw x4, 56(x1)

loop:
  ...
```

When we compile and flash again, we get a blinking light! Huzzah!

## Cleaning Up

Let's make a simple makefile to build, flash, and clean the program. Enter
the following into a file called **Makefile**

```makefile
CARGS = -march=rv32imac -mabi=ilp32 -nostdlib -Tlink.ld

all: blinky

blinky: blinky.s link.ld
	riscv64-unknown-elf-gcc $(CARGS) ./blinky.s -o blinky

flash: blinky
	openocd -f board/sifive-hifive1-revb.cfg -c "program ./blinky verify reset exit"

.PHONY: clean
clean:
	rm -fv blinky
```

Now we can type "make" to build our program, "make flash" to flash it, and
"make clean" to remove the resulting binary.

There you have it. A simple blinky program, in ≈25 lines of code + a small
makefile. Pretty cool right! Next we'll see how to improve our assembly to make
more readable, learn about the RISC-V calling convention, and dive into
adding support for c code to our framework.
