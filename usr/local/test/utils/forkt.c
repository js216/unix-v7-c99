#include <stdio.h>

int getpid(void), wait(int *st), sfork(void);
extern int par_uid;
int rawpid, rawpar, rawchild;
__asm__(
"	.text\n"
"	.globl sfork\n"
"sfork:\n"
"	push {r7}\n"
"	mov r7, #2\n"
"	svc #0\n"
"	b 1f\n"
"	ldr r1, =rawpar\n"
"	str r0, [r1]\n"
"	pop {r7}\n"
"	mov r0, #1\n"
"	bx lr\n"
"1:	ldr r1, =rawchild\n"
"	str r0, [r1]\n"
"	pop {r7}\n"
"	mov r0, #0\n"
"	bx lr\n"
"	.ltorg\n");

int
main(void)
{
	int me, pid, st;

	me = getpid();
	if (sfork() == 0)
		exit(rawchild == me ? 3 : 4);
	wait(&st);
	printf("raw: child sees parent pid %s, parent skipped branch "
	    "%s\n",
	    (st>>8) == 3 ? "yes" : "no", rawpar > me ? "yes" : "no");
	fflush(stdout);
	pid = fork();
	if (pid == 0)
		exit(par_uid == me ? 5 : 6);
	if (pid < 0)
		printf("fork failed\n");
	wait(&st);
	printf("libc: child par_uid ok %s, parent got pid %s\n",
	    (st>>8) == 5 ? "yes" : "no", pid > me ? "yes" : "no");
	return 0;
}
