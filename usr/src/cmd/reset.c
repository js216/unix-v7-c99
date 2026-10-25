/*
 * Reset the STM32MP1 board, through RCC_MP_GRSTCSETR, into the
 * boot ROM's USB loader. The kernel's mark in block 0 of the
 * disk makes the next kernel take the last boot for one which
 * failed, and spoil its own copies on the card (see sd.c).
 */

#include <stdio.h>

int	blk[128];

int
main(void)
{
	int mem, d, v;

	sync();
	blk[0] = 0x544f4f42;
	if((d = open("/dev/rrk0", 1)) < 0 || write(d, (char *)blk, 512) != 512) {
		perror("/dev/rrk0");
		exit(1);
	}
	if((mem = open("/dev/mem", 1)) < 0) {
		perror("/dev/mem");
		exit(1);
	}
	v = 1;
	lseek(mem, 0x50000114L, 0);
	write(mem, (char *)&v, 4);
	perror("reset");
	exit(1);
}
