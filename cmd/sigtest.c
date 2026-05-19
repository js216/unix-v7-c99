/* sigtest.c -- port-local smoke test for SIG_DFL terminate semantics
 * and the SIGPIPE-on-closed-reader injection.  Forks a child, has the
 * child raise a signal on itself (or do a doomed write to a pipe with
 * the read end closed), and reports the child's wait() status. */
#include <stdio.h>
#include <signal.h>

int fork(void);
int wait(int *);
int kill(int pid, int sig);
int getpid(void);
int pipe(int *fds);
int write(int fd, char *buf, int n);
int close(int fd);

static void
report(char *what, int pid)
{
	int status = 0;
	int reaped = wait(&status);
	int low, high;
	if (reaped != pid) {
		printf("%s: wait returned %d, expected %d\n", what, reaped, pid);
		return;
	}
	low = status & 0xff;
	high = (status >> 8) & 0xff;
	if (low == 0)
		printf("%s: exit code=%d\n", what, high);
	else
		printf("%s: killed sig=%d core=%d\n",
		    what, low & 0x7f, (low >> 7) & 1);
}

static void
test_sigkill(void)
{
	int pid = fork();
	if (pid == 0) {
		kill(getpid(), SIGKILL);
		printf("sigkill: STILL ALIVE (bug)\n");
		_exit(99);
	}
	report("sigkill", pid);
}

static void
test_sigpipe_via_kill(void)
{
	int pid = fork();
	if (pid == 0) {
		kill(getpid(), SIGPIPE);
		printf("sigpipe(kill): STILL ALIVE (bug)\n");
		_exit(99);
	}
	report("sigpipe(kill)", pid);
}

static void
test_sigterm(void)
{
	int pid = fork();
	if (pid == 0) {
		kill(getpid(), SIGTERM);
		printf("sigterm: STILL ALIVE (bug)\n");
		_exit(99);
	}
	report("sigterm", pid);
}

static void
test_normal_exit(void)
{
	int pid = fork();
	if (pid == 0)
		_exit(42);
	report("exit42", pid);
}

int
main(int argc, char *argv[])
{
	(void)argc; (void)argv;
	test_normal_exit();
	test_sigkill();
	test_sigterm();
	test_sigpipe_via_kill();
	return 0;
}
