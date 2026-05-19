/* watch -- run a command repeatedly, with header showing the time.
 * Usage:  watch [-n SECS] CMD [ARG...]
 * Default interval is 2 seconds.  Doesn't clear the screen like GNU
 * watch (v7 has no escape-sequence handling here); just prints a
 * separator banner between iterations.  Ctrl-C terminates. */

#include <stdio.h>
extern int fork(void), execvp(char *file, char **argv);
extern int wait(int *), atoi(char *);
extern char *ctime(long *);

int
main(int argc, char *argv[])
{
	int secs = 2;
	int start = 1;
	int pid, status;
	long t;

	if (start < argc && argv[start][0] == '-' && argv[start][1] == 'n' &&
	    argv[start][2] == '\0' && start + 1 < argc) {
		secs = atoi(argv[start + 1]);
		if (secs <= 0) secs = 2;
		start += 2;
	}
	if (start >= argc) {
		fprintf(stderr, "usage: watch [-n SECS] CMD [ARGS...]\n");
		exit(1);
	}
	for (;;) {
		(void)time(&t);
		printf("==> every %ds: %s   %s", secs, argv[start], ctime(&t));
		fflush(stdout);
		pid = fork();
		if (pid == 0) {
			execvp(argv[start], &argv[start]);
			fprintf(stderr, "watch: %s: cannot execute\n", argv[start]);
			exit(127);
		}
		if (pid < 0) {
			fprintf(stderr, "watch: fork failed\n");
			exit(1);
		}
		while (wait(&status) != pid)
			;
		sleep(secs);
	}
}
