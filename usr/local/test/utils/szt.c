#include <stdio.h>

int
main(void)
{
	fork();
	alarm(3);
	pause();
	return 0;
}
