#include <stdio.h>
#include <signal.h>

void
abort(void)
{
	kill(getpid(), SIGIOT);
	_exit(1);
}
