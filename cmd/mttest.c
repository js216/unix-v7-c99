/* mttest.c -- port-local multitasking smoke test.  Verifies that the
 * parent can run concurrently with a child it forked: parent sends a
 * SIGTERM to a child that is mid-sleep and observes the child dying by
 * that signal rather than completing its sleep naturally.  Without
 * multitasking the parent cannot run until the child exits on its own,
 * so the kill() finds a non-existent pid and the child reports a clean
 * exit. */
#include <stdio.h>
#include <signal.h>

int fork(void);
int wait(int *);
int kill(int pid, int sig);
unsigned sleep(unsigned);

int
main(int argc, char *argv[])
{
	int pid, status = 0;
	(void)argc; (void)argv;
	pid = fork();
	if (pid == 0) {
		/* Long enough to outlast the parent's kill but short enough
		 * that a single-threaded run still completes within
		 * pexpect's 60-second timeout. */
		sleep(10);
		_exit(0);
	}
	/* Parent: in a multitasking kernel this runs concurrently with the
	 * child's sleep.  In the single-threaded port the parent is frozen
	 * until the child exits naturally, so the kill below lands after
	 * the child is already gone. */
	kill(pid, SIGTERM);
	wait(&status);
	if ((status & 0x7f) == 15)
		printf("PASS killed sig=15\n");
	else if ((status & 0xff) == 0)
		printf("FAIL child completed naturally (no multitasking)\n");
	else
		printf("FAIL unexpected status=0x%x\n", status);
	return 0;
}
