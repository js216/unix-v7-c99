#include <stdio.h>
#include <a.out.h>
#include "h/param.h"
#include "h/proc.h"
#include "h/dir.h"
#include "h/user.h"

struct nlist nl[] = {
	{ "_proc", 0, 0 },
	{ "", 0, 0 },
};
struct proc pr;
struct user uk, um;

int
main(void)
{
	int k, m, i, pid;
	long pa;

	k = open("/dev/kmem", 0);
	m = open("/dev/mem", 0);
	nlist("/unix", nl);
	printf("proc above USERSIZE %d\n", nl[0].n_value >= USERSIZE);
	pid = getpid();
	lseek(k, (long)nl[0].n_value, 0);
	for (i = 0; i < NPROC; i++) {
		read(k, (char *)&pr, sizeof(pr));
		if (pr.p_stat && pr.p_pid == pid)
			break;
	}
	printf("found self %d\n", i < NPROC);
	pa = ctob((unsigned long)pr.p_addr);
	lseek(k, (long)UBASE, 0);
	printf("kmem u %d\n", read(k, (char *)&uk, sizeof(uk)) == sizeof(uk));
	lseek(m, pa, 0);
	printf("mem u %d\n", read(m, (char *)&um, sizeof(um)) == sizeof(um));
	printf("comm %.14s %.14s procp same %d\n", uk.u_comm, um.u_comm,
		uk.u_procp == um.u_procp);
	lseek(m, (long)UBASE, 0);
	printf("mem at UBASE %d\n", read(m, (char *)&um, 4));
	lseek(k, pa, 0);
	printf("kmem at physical %d\n", read(k, (char *)&uk, 4));
	return 0;
}
