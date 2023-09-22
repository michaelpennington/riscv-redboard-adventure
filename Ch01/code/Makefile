CARGS = -march=rv32imac -mabi=ilp32 -nostdlib -Tlink.ld

blinky: blinky.s link.ld
	riscv64-unknown-elf-gcc $(CARGS) ./blinky.s -o blinky

flash: blinky
	openocd -f board/sifive-hifive1-revb.cfg -c "program ./blinky verify reset exit"

.PHONY: clean
clean:
	rm -fv blinky

all: blinky

