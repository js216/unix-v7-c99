#include <stdio.h>
#include <signal.h>

int tsig4(int pid, int sig);
__asm__(
"	.syntax unified\n"
"	.text\n"
"	.thumb\n"
"	.globl tsig4\n"
"	.type tsig4, %function\n"
"	.thumb_func\n"
"tsig4:\n"
"	push {r4, r7, lr}\n"
"	movs r4, #0\n"
"	movs r7, #37\n"
"	cmp r0, r0\n"
"	itete eq\n"
"	svceq #0\n"
"	addne r4, #1\n"
"	addeq r4, #2\n"
"	addne r4, #4\n"
"	mov r0, r4\n"
"	pop {r4, r7, pc}\n"
"	.align 2\n"
"	.arm\n");

volatile int hits;

static void
count(int sig)
{
	signal(sig, count);
	hits++;
}

int
main(void)
{
	signal(SIGALRM, count);
	printf("thumb it4: %d hits %d\n", tsig4(getpid(), SIGALRM), hits);
	return 0;
}
