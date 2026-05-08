/*
 * kill - send signal to process
 */

#include <signal.h>
#include <stdio.h>

int kill(int pid, int sig);
int atoi(char *s);
void exit(int n);
char *sys_errlist[] = { "error" };
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
		printf("usage: kill [ -signo ] pid ...\n");
		exit(2);
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
