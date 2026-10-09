#include <stdio.h>
void	_cleanup();

void
exit(n)
int n;
{
	_cleanup();
	_exit(n);
}
