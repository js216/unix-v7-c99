#include <stdio.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>

int tsig(int pid, int sig);
int tudf(void);
__asm__(
"	.syntax unified\n"
"	.text\n"
"	.thumb\n"
"	.globl tsig\n"
"	.type tsig, %function\n"
"	.thumb_func\n"
"tsig:\n"
"	push {r4, r7, lr}\n"
"	movs r4, #0\n"
"	movs r7, #37\n"
"	cmp r0, r0\n"
"	ite eq\n"
"	svceq #0\n"
"	movne r4, #1\n"
"	mov r0, r4\n"
"	pop {r4, r7, pc}\n"
"	.globl tudf\n"
"	.type tudf, %function\n"
"	.thumb_func\n"
"tudf:\n"
"	movs r0, #7\n"
"	udf.w #0\n"
"	udf.n #0\n"
"	bx lr\n"
"	.align 2\n"
"	.arm\n");

volatile int hits;

static void
count(int sig)
{
	signal(sig, count);
	hits++;
}

static void
tick(int sig)
{
	signal(sig, tick);
	hits++;
	alarm(1);
}

int
main(int argc, char **argv)
{
	volatile long long a = 0x123456789abcLL, b = 7, s = 0;
	long n;
	struct stat sb;
	int st;

	if (argc > 2) {
		printf("utime %d\n",
		    utime(argv[2], (long long *)0x50000000));
		fflush(stdout);
		if (fork() == 0) {
			stat(argv[2], &sb);
			exit(0);
		}
		signal(SIGALRM, count);
		alarm(10);
		printf("%s\n",
		    wait(&st) < 0 ? "inode locked" : "stat done");
		return 0;
	}
	signal(SIGALRM, count);
	printf("thumb it: %d hits %d\n", tsig(getpid(), SIGALRM), hits);
	hits = 0;
	signal(SIGILL, count);
	printf("thumb udf: r0 %d hits %d\n", tudf(), hits);
	hits = 0;
	signal(SIGALRM, tick);
	alarm(1);
	for (n = 0; hits < 4; n++)
		s += a / (b + (n & 15));
	printf("ldiv: hits %d\n", hits);
	return 0;
}
