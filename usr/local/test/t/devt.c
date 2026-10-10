#include <stdio.h>

int
main(void)
{
	volatile int *p = (volatile int *)0x09000018;

	printf("reading uart flag register from user mode\n");
	printf("got %x\n", *p);
	return 0;
}
