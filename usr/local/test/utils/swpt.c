#include <stdio.h>
#include <a.out.h>
#include "h/param.h"
#include "h/proc.h"
#include "h/dir.h"
#include "h/user.h"
#include "h/map.h"

struct nlist nl[] = {
	{ "_proc", 0, 0 },
	{ "_nproc", 0, 0 },
	{ "_coremap", 0, 0 },
	{ "", 0, 0 },
};
struct proc pr;
struct user uk;
int nproc, pid[64];
volatile int mark;
char *sbrk(int incr);
int lock(int flag);

static void
getproc(int id)
{
	int k, i;

	k = open("/dev/kmem", 0);
	lseek(k, (long)nl[1].n_value, 0);
	read(k, (char *)&nproc, sizeof(nproc));
	lseek(k, (long)nl[0].n_value, 0);
	for (i = 0; i < nproc; i++) {
		read(k, (char *)&pr, sizeof(pr));
		if (pr.p_stat && pr.p_pid == id)
			break;
	}
	lseek(k, (long)UBASE, 0);
	read(k, (char *)&uk, sizeof(uk));
	close(k);
}

static int
physmark(void)
{
	int m, v;

	getproc(getpid());
	m = open("/dev/mem", 0);
	lseek(m, (long)ctob((unsigned long)(pr.p_addr+USIZE)) +
	    ((unsigned)&mark - ctob((unsigned long)uk.u_tsize)), 0);
	v = 0;
	read(m, (char *)&v, sizeof(v));
	close(m);
	return v;
}

static int
corefree(void)
{
	struct map m;
	int k, n;

	k = open("/dev/kmem", 0);
	lseek(k, (long)nl[2].n_value, 0);
	n = 0;
	while (read(k, (char *)&m, sizeof(m)) == sizeof(m) && m.m_size)
		n += m.m_size;
	close(k);
	return n;
}

int
main(int argc, char **argv)
{
	int n, i, c, st;
	unsigned j, sz;
	char *p;

	if (argc < 2)
		return 1;
	sz = atoi(argv[1]) << 20;
	nlist("/unix", nl);
	p = sbrk(sz);
	for (j = 0; j < sz; j += 4096)
		p[j] = 1;
	lock(1);
	mark = 1;
	printf("before %d\n", physmark() == mark);
	fflush(stdout);
	for (n = 0; n < 64 && corefree() >= pr.p_size; n++)
		if ((pid[n] = fork()) == 0) {
			pause();
			_exit(0);
		}
	printf("full %d\n", corefree() < pr.p_size);
	fflush(stdout);
	if ((c = fork()) == 0) {
		mark = 3;
		printf("child %d\n", physmark() == mark);
		exit(0);
	}
	while (wait(&st) != c)
		;
	printf("parent %d\n", mark == 1 && physmark() == mark);
	for (i = 0; i < n; i++)
		kill(pid[i], 9);
	while (wait(&st) != -1)
		;
	return 0;
}
