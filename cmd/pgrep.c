/* pgrep / pkill -- find or signal processes whose command name matches
 * a pattern.  Uses the kernel's /dev/mem + nlist("_proc","_pcomm")
 * window (same approach as ps(1)).
 *
 * Usage:
 *   pgrep NAME           -- print pids whose pcomm equals NAME
 *   pkill NAME           -- send SIGTERM to those pids
 *   pkill -SIG NAME      -- send signal SIG (e.g., -9 for KILL) */

#include <stdio.h>
#include <a.out.h>
#include <sys/param.h>
#include <sys/types.h>
struct tty;
#include <sys/dir.h>
#include "../h/user.h"
#include "../h/proc.h"

extern long lseek(int fd, long offset, int ptrname);
extern int kill(int pid, int sig);

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
	char *pat;
	int mem;
	int i, j, killmode = 0, sig = 15, matched = 0;
	int start = 1;
	int n = 0;
	/* Determine mode: pgrep vs pkill by argv[0] basename. */
	char *prog = argv[0], *p;
	for (p = prog; *p; p++) if (*p == '/') prog = p + 1;
	if (prog[0] == 'p' && prog[1] == 'k') killmode = 1;
	if (killmode && argc >= 2 && argv[1][0] == '-' && argv[1][1] != '\0') {
		char *sp = argv[1] + 1;
		int v = 0;
		while (*sp >= '0' && *sp <= '9') v = v*10 + (*sp++ - '0');
		if (v > 0) sig = v;
		start++;
	}
	if (start >= argc) {
		fprintf(stderr, "usage: %s [-sig] PATTERN\n", prog);
		exit(2);
	}
	pat = argv[start];
	if (chdir("/dev") < 0) {
		fprintf(stderr, "%s: can't cd /dev\n", prog);
		exit(2);
	}
	nlist("/unix", nl);
	if (nl[0].n_type == 0 || nl[1].n_type == 0) {
		fprintf(stderr, "%s: no namelist\n", prog);
		exit(2);
	}
	mem = open("/dev/mem", 0);
	if (mem < 0) {
		fprintf(stderr, "%s: can't open /dev/mem\n", prog);
		exit(2);
	}
	for (i = 0; i < NPROC; i++) {
		lseek(mem, (long)nl[0].n_value + (long)i * (long)sizeof(mproc), 0);
		if (read(mem, (char *)&mproc, sizeof(mproc)) != sizeof(mproc)) break;
		if (mproc.p_stat == 0) continue;
		lseek(mem, (long)nl[1].n_value + (long)i * 16, 0);
		if (read(mem, nb, 16) != 16) continue;
		nb[15] = '\0';
		/* Strict-equal match for now. */
		for (j = 0; nb[j] && pat[j] && nb[j] == pat[j]; j++) ;
		if (nb[j] != pat[j]) continue;
		matched++;
		if (killmode) {
			if (kill(mproc.p_pid, sig) < 0)
				fprintf(stderr, "%s: kill %d failed\n", prog, mproc.p_pid);
		} else {
			printf("%d\n", mproc.p_pid);
		}
		n++;
	}
	(void)n;
	exit(matched ? 0 : 1);
}
