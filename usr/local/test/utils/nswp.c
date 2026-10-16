#include <stdio.h>
#include <a.out.h>
#include "h/param.h"
#include "h/proc.h"
#include "h/map.h"

struct nlist nl[] = {
	{ "_proc", 0, 0 },
	{ "_coremap", 0, 0 },
	{ "", 0, 0 },
};
struct proc pr;
int pid[64], fd[2];
extern int errno;
char *sbrk(int incr);

static void
getproc(int id)
{
	int k, i;

	k = open("/dev/kmem", 0);
	lseek(k, (long)nl[0].n_value, 0);
	for (i = 0; i < NPROC; i++) {
		read(k, (char *)&pr, sizeof(pr));
		if (pr.p_stat && pr.p_pid == id)
			break;
	}
	close(k);
}

static int
corefree(void)
{
	struct map m;
	int k, n;

	k = open("/dev/kmem", 0);
	lseek(k, (long)nl[1].n_value, 0);
	n = 0;
	while (read(k, (char *)&m, sizeof(m)) == sizeof(m) && m.m_size)
		n += m.m_size;
	close(k);
	return n;
}

static int
stk(void)
{
	volatile char a[8<<20];

	a[0] = 1;
	return a[0];
}

static void
child(int act)
{
	char c;

	read(fd[0], &c, 1);
	if (act == 'g')
		_exit(stk());
	if (act == 'x')
		execl("/usr/local/test/utils/bigb", "bigb", (char *)0);
	_exit(0);
}

int
main(int argc, char **argv)
{
	int n, i, c, st, size;
	unsigned j, sz;
	char *p;

	if (argc < 3)
		return 1;
	sz = atoi(argv[1]) << 20;
	nlist("/unix", nl);
	pipe(fd);
	p = sbrk(sz);
	for (j = 0; j < sz; j += 4096)
		p[j] = 1;
	getproc(getpid());
	size = pr.p_size;
	for (n = 0; n < 64 && corefree() >= size; n++)
		if ((pid[n] = fork()) == 0)
			child(argv[2][0]);
	if ((c = fork()) == 0)
		child(0);
	pid[n++] = c;
	getproc(c);
	printf("core full %d, child swapped %d\n", corefree() < size,
	    c > 0 && (pr.p_flag & SLOAD) == 0);
	switch (argv[2][0]) {
	case 's':
		p = sbrk(sz / 5);
		printf("sbrk %d errno %d\n", p == (char *)-1, errno);
		c = fork();
		if (c == 0)
			_exit(0);
		printf("fork %d errno %d\n", c, errno);
		break;
	case 'g':
	case 'x':
		write(fd[1], "x", 1);
		c = wait(&st);
		printf("child status %d\n", st & 0177);
		break;
	}
	for (i = 0; i < n; i++)
		if (pid[i] > 0)
			kill(pid[i], 9);
	while (wait(&st) != -1)
		;
	printf("survived\n");
	return 0;
}
