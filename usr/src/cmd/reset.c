/*
 * Reset the STM32MP1 board, through RCC_MP_GRSTCSETR.
 */

#include <stdio.h>

int
main(void)
{
	int mem, v;

	sync();
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
