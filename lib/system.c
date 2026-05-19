#include	<stdio.h>
#include	<signal.h>

int
system(s)
char *s;
{
	int status, pid, w;
	register int (*istat)(), (*qstat)();

	if ((pid = fork()) == 0) {
		execl("/bin/sh", "sh", "-c", s, 0);
		_exit(127);
	}
	istat = (int (*)())signal(SIGINT, (int)SIG_IGN);
	qstat = (int (*)())signal(SIGQUIT, (int)SIG_IGN);
	while ((w = wait(&status)) != pid && w != -1)
		;
	if (w == -1)
		status = -1;
	signal(SIGINT, (int)istat);
	signal(SIGQUIT, (int)qstat);
	return(status);
}
