/*
 * kill - send signal to process
 */

#include <signal.h>
#include <stdio.h>

int kill(int pid, int sig);
int atoi(char *s);
void exit(int n);
extern char *sys_errlist[];
int errno;

int
main(argc, argv)
int argc;
char **argv;
{
	register int signo, pid, res;
	int errlev;

	errlev = 0;
	if (argc <= 1) {
	usage:
		printf("usage: kill [ -signo ] pid ...\n       kill -l\n");
		exit(2);
	}
	/* -l : list signal names (v7 had 16 signals; SIGTERM=15). */
	if (argv[1][0] == '-' && argv[1][1] == 'l' && argv[1][2] == '\0') {
		static char *names[] = {
			0, "HUP", "INT", "QUIT", "ILL", "TRAP", "IOT", "EMT",
			"FPE", "KILL", "BUS", "SEGV", "SYS", "PIPE", "ALRM",
			"TERM"
		};
		int s;
		for (s = 1; s <= 15; s++)
			printf("%2d) SIG%s\n", s, names[s]);
		return 0;
	}
	if (*argv[1] == '-') {
		signo = atoi(argv[1]+1);
		argc--;
		argv++;
	} else
		signo = SIGTERM;
	argv++;
	while (argc > 1) {
		if (**argv<'0' || **argv>'9')
			goto usage;
		res = kill(pid = atoi(*argv), signo);
		if (res<0) {
			printf("%u: %s\n", pid, sys_errlist[errno]);
			errlev = 1;
		}
		argc--;
		argv++;
	}
	return(errlev);
}
