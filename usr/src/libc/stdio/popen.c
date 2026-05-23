#include <stdio.h>
#include <signal.h>
#define	tst(a,b)	(*mode == 'r'? (b) : (a))
#define	RDR	0
#define	WTR	1
static	int	popen_pid[20];

FILE *
popen(cmd,mode)
char	*cmd;
char	*mode;
{
	int p[2];
	register int myside, hisside, pid;
	int stdside;

	if(pipe(p) < 0)
		return NULL;
	myside = tst(p[WTR], p[RDR]);
	hisside = tst(p[RDR], p[WTR]);
	if((pid = fork()) == 0) {
		/* myside and hisside reverse roles in child */
		close(myside);
		stdside = tst(0, 1);
		close(stdside);
		dup(hisside);
		close(hisside);
		execl("/bin/sh", "sh", "-c", cmd, 0);
		_exit(1);
	}
	if(pid == -1)
		return NULL;
	popen_pid[myside] = pid;
	close(hisside);
	return(fdopen(myside, mode));
}

int
pclose(ptr)
FILE *ptr;
{
	register int f, r, (*hstat)(), (*istat)(), (*qstat)();
	int status;

	f = fileno(ptr);
	fclose(ptr);
	istat = (int (*)())signal(SIGINT, (int)SIG_IGN);
	qstat = (int (*)())signal(SIGQUIT, (int)SIG_IGN);
	hstat = (int (*)())signal(SIGHUP, (int)SIG_IGN);
	while((r = wait(&status)) != popen_pid[f] && r != -1)
		;
	if(r == -1)
		status = -1;
	signal(SIGINT, (int)istat);
	signal(SIGQUIT, (int)qstat);
	signal(SIGHUP, (int)hstat);
	return(status);
}
