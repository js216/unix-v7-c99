#include <stdio.h>
#include <errno.h>
#include "h/param.h"
#include "h/dir.h"
#include "h/user.h"
#include "h/reg.h"

int ptrace(int req, int pid, int *addr, int data);
int glob = 5;

int
main(void)
{
	int pid, st, ar0, r, off;

	pid = fork();
	if (pid == 0) {
		ptrace(0, 0, 0, 0);
		r = kill(getpid(), 2);
		exit(r + glob);
	}
	wait(&st);
	printf("stop %o\n", st);
	off = (int)&((struct user *)0)->u_ar0;
	ar0 = ptrace(3, pid, (int *)off, 0);
	off = ar0 - UBASE;
	printf("glob %d\n", ptrace(2, pid, &glob, 0));
	ptrace(5, pid, &glob, -1);
	errno = 5;
	r = ptrace(2, pid, &glob, 0);
	printf("neg %d errno %d\n", r, errno);
	r = ptrace(3, pid, (int *)(off + R0*4), 0);
	printf("r0 %d pcok %d\n", r,
	    ptrace(3, pid, (int *)(off + PC*4), 0) > 0x10);
	printf("w %d\n", ptrace(6, pid, (int *)(off + R0*4), 40));
	printf("wr9 %d\n", ptrace(6, pid, (int *)(off + 9*4), 1));
	ptrace(6, pid, (int *)(off + PSR*4), -1);
	printf("rps %x\n", ptrace(3, pid, (int *)(off + PSR*4), 0));
	printf("wps %d\n", ptrace(6, pid, (int *)(off + PSR*4), 0x1df));
	printf("rps %x\n", ptrace(3, pid, (int *)(off + PSR*4), 0));
	ptrace(5, pid, &glob, 2);
	ptrace(7, pid, (int *)1, 0);
	wait(&st);
	printf("exit %d\n", st >> 8);
	return 0;
}
