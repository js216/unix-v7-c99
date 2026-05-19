/* pidof -- print pids of running programs matching NAME on a single
 * line (space-separated).  Uses the kernel's proc[] + pcomm[] tables
 * via nlist("/unix") + /dev/mem, same as ps/pgrep. */

#include <stdio.h>
#include <a.out.h>
#include <sys/param.h>
#include <sys/types.h>
struct tty;
#include <sys/dir.h>
#include "../h/user.h"
#include "../h/proc.h"

extern long lseek();

struct nlist nl[] = {
	{ "_proc", 0, 0 },
	{ "_pcomm", 0, 0 },
	{ "", 0, 0 },
};

int
main(int argc, char *argv[])
{
	struct proc mproc;
	char nb[16];
	int mem, i, j, matched = 0;

	if (argc < 2) {
		fprintf(stderr, "usage: pidof NAME\n");
		exit(1);
	}
	if (chdir("/dev") < 0) {
		fprintf(stderr, "pidof: can't cd /dev\n");
		exit(1);
	}
	nlist("/unix", nl);
	if (nl[0].n_type == 0 || nl[1].n_type == 0) {
		fprintf(stderr, "pidof: no namelist\n");
		exit(1);
	}
	if ((mem = open("/dev/mem", 0)) < 0) {
		fprintf(stderr, "pidof: cannot open /dev/mem\n");
		exit(1);
	}
	for (i = 0; i < NPROC; i++) {
		lseek(mem, (long)nl[0].n_value + (long)i * (long)sizeof(mproc), 0);
		if (read(mem, (char *)&mproc, sizeof(mproc)) != sizeof(mproc)) break;
		if (mproc.p_stat == 0) continue;
		lseek(mem, (long)nl[1].n_value + (long)i * 16, 0);
		if (read(mem, nb, 16) != 16) continue;
		nb[15] = '\0';
		for (j = 0; nb[j] && argv[1][j] && nb[j] == argv[1][j]; j++) ;
		if (nb[j] != argv[1][j]) continue;
		if (matched) putchar(' ');
		printf("%d", mproc.p_pid);
		matched++;
	}
	if (matched) putchar('\n');
	exit(matched ? 0 : 1);
}
