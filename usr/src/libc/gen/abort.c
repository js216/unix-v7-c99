#include <stdio.h>
#include <signal.h>

void
abort()
{
	kill(getpid(), SIGIOT);
	_exit(1);
}
