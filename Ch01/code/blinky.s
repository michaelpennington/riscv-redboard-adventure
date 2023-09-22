# blinky.s
.globl _start
_start:
  lui x1, 0x10012
  addi x2, x0, 0x20
  xori x3, x2, -1

  sw x2, 8(x1)
  sw x3, 4(x1)
  lw x4, 56(x1)
  and x4, x4, x3
  sw x4, 56(x1)
loop:
  lui x4, 0x600
1:
  addi x4, x4, -1
  bne x4, x0, 1b

  lw x4, 12(x1)
  xor x4, x4, x2
  sw x4, 12(x1)

  j loop
