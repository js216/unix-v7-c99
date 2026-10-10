#include <stdio.h>

int ptrace(int req, int pid, int *addr, int data);

static int
f(void)
{
	return 1;
}

int (*volatile fp)(void) = f;

int
main(int argc, char **argv)
{
	int pid, st, a, *fa;

	if (argc > 2) {
		a = (*fp)();
		kill(getpid(), 2);
		exit(10*a + (*fp)());
	}
	fa = (int *)(unsigned)f;
	pid = fork();
	if (pid == 0) {
		ptrace(0, 0, 0, 0);
		execl(argv[1], argv[1], "c", "c", (char *)0);
		exit(99);
	}
	wait(&st);
	printf("exec stop %o\n", st);
	ptrace(7, pid, (int *)1, 0);
	wait(&st);
	printf("kill stop %o\n", st);
	printf("before %x\n", ptrace(1, pid, fa, 0));
	printf("w %x", ptrace(4, pid, fa, 0xe3a00002));
	printf(" %x\n", ptrace(4, pid, fa + 1, 0xe12fff1e));
	printf("after %x\n", ptrace(1, pid, fa, 0));
	ptrace(7, pid, (int *)1, 0);
	wait(&st);
	printf("exit %d\n", st >> 8);
	return 0;
}
