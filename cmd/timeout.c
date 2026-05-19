/* timeout SECS CMD [ARG...]
 *
 * Run CMD with a deadline of SECS.  Implementation: fork a watchdog
 * child that sleep(SECS)s then kill()s the target; parent fork+execs
 * the command; main process wait()s for the command, then kills the
 * watchdog and returns the command's exit code (or 124 if it was
 * killed by the watchdog).  Avoids SIGALRM since v7's wait() isn't
 * always interrupted by signals in this port. */

#include <stdio.h>
extern int fork(void), execvp(char *file, char **argv);
extern int wait(int *), kill(int pid, int sig);

int
main(int argc, char *argv[])
{
	int secs, target_pid, dog_pid, status, rc;
	if (argc < 3) {
		fprintf(stderr, "usage: timeout SECONDS COMMAND [ARG...]\n");
		exit(2);
	}
	secs = atoi(argv[1]);
	if (secs <= 0) {
		fprintf(stderr, "timeout: bad duration %s\n", argv[1]);
		exit(2);
	}
	target_pid = fork();
	if (target_pid < 0) {
		fprintf(stderr, "timeout: fork failed\n");
		exit(2);
	}
	if (target_pid == 0) {
		execvp(argv[2], &argv[2]);
		fprintf(stderr, "timeout: %s: cannot execute\n", argv[2]);
		exit(127);
	}
	dog_pid = fork();
	if (dog_pid < 0) {
		fprintf(stderr, "timeout: fork failed (watchdog)\n");
		kill(target_pid, 15);
		exit(2);
	}
	if (dog_pid == 0) {
		sleep(secs);
		kill(target_pid, 15);	/* SIGTERM */
		exit(0);
	}
	rc = 0;
	for (;;) {
		int w = wait(&status);
		if (w == target_pid) {
			kill(dog_pid, 15);	/* clean up watchdog */
			if ((status & 0177) == 15) rc = 124;
			else rc = (status >> 8) & 0xff;
			break;
		}
		if (w == dog_pid) {
			/* Watchdog finished first -- target was killed by it.
			 * Reap target via another wait and synthesize 124. */
			if (wait(&status) == target_pid) rc = 124;
			break;
		}
		if (w < 0) break;
	}
	/* Reap watchdog if still pending. */
	(void)wait(&status);
	exit(rc);
}
