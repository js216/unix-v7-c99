#include <stdio.h>
#include "h/param.h"
#include "h/dir.h"
#include "h/user.h"
#include "h/reg.h"

int ptrace(int req, int pid, int *addr, int data);
extern int errno;
void xexec(char *name, char **argv);
__asm__(
"	.text\n"
"	.globl xexec\n"
"xexec:\n"
"	ldr r2, =0x22222222\n"
"	ldr r3, =0x33333333\n"
"	ldr r4, =0x44444444\n"
"	ldr r5, =0x55555555\n"
"	ldr r6, =0x66666666\n"
"	ldr r8, =0x88888888\n"
"	ldr r9, =0x99999999\n"
"	ldr r10, =0xaaaaaaaa\n"
"	ldr r11, =0xbbbbbbbb\n"
"	ldr r12, =0xcccccccc\n"
"	ldr lr, =0xeeeeeeee\n"
"	mov r7, #11\n"
"	svc #0\n"
"	mov r0, #99\n"
"	mov r7, #1\n"
"	svc #0\n"
"	.ltorg\n");

int
main(int argc, char **argv)
{
	static char *av[] = { "regs", "child", 0 };
	int pid, st, ar0, off, i, r;

	if (argc > 1 && argv[1][0])
		return 7;
	pid = fork();
	if (pid == 0) {
		ptrace(0, 0, 0, 0);
		xexec("/usr/local/test/utils/regs", av);
	}
	wait(&st);
	printf("stop %o\n", st);
	off = (int)&((struct user *)0)->u_ar0;
	ar0 = ptrace(3, pid, (int *)off, 0);
	off = ar0 - UBASE;
	for (i = 0; i < PC; i++) {
		if (i == R6)
			continue;
		r = ptrace(3, pid, (int *)(off + i*4), 0);
		if (r != 0)
			printf("r%d = %x\n", i, r);
	}
	errno = 0;
	r = ptrace(9, pid, (int *)1, 0);
	printf("ptrace 9: %d errno %d\n", r, errno);
	ptrace(7, pid, (int *)1, 0);
	wait(&st);
	printf("exit %d\n", st >> 8);
	return 0;
}
