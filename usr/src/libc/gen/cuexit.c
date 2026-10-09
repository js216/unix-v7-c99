#include <stdio.h>

void
exit(int n)
{
	_cleanup();
	_exit(n);
}
