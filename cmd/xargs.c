/* xargs -- build argv from stdin lines and run a command.  V7 didn't
 * ship xargs; this is a minimal subset:
 *   xargs [-n N] [-I REPLSTR] cmd [initial-args...]
 * Reads stdin a line at a time, treats each whitespace-separated token
 * as an argument.  Without -I/-n, batches all tokens up to MAXBATCH
 * and exec's once.  With -n, exec's after every N tokens.  With -I,
 * exec's once per input line, replacing REPLSTR in any initial-arg
 * with the line. */

#include <stdio.h>

extern int execvp(char *file, char **argv);
extern int fork(void);
extern int wait(int *);
extern void exit(int);

#define MAXBATCH 64

static int
isspc(int c)
{
	return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f';
}

static int
runbatch(char **batch, int nbatch)
{
	int pid, status, rc;

	if (nbatch <= 1)
		return 0;
	batch[nbatch] = (char *)0;
	pid = fork();
	if (pid == 0) {
		execvp(batch[0], batch);
		fprintf(stderr, "xargs: %s: cannot execute\n", batch[0]);
		exit(127);
	}
	if (pid < 0) {
		fprintf(stderr, "xargs: fork failed\n");
		return 1;
	}
	rc = 0;
	while ((wait(&status)) != pid) {
		if (status != 0) rc = 1;
	}
	if (status != 0) rc = 1;
	return rc;
}

/* Substitute occurrences of `repl` in `src` with `val`; writes into
 * the caller-supplied buffer `out` of size `outsz`.  Returns `out`. */
static char *
subst(char *src, char *repl, char *val, char *out, int outsz)
{
	int oi = 0, si = 0, rl, vl, vi;
	for (rl = 0; repl[rl]; rl++) ;
	for (vl = 0; val[vl]; vl++) ;
	while (src[si] && oi < outsz - 1) {
		int match = 1, j;
		for (j = 0; j < rl; j++)
			if (src[si+j] != repl[j]) { match = 0; break; }
		if (match) {
			for (vi = 0; vi < vl && oi < outsz - 1; vi++)
				out[oi++] = val[vi];
			si += rl;
		} else {
			out[oi++] = src[si++];
		}
	}
	out[oi] = '\0';
	return out;
}

int
main(int argc, char *argv[])
{
	char *batch[MAXBATCH + 1];
	char buf[8192], *p, *tok;
	int nbatch, i, c, base, start = 1;
	int nflag = 0;
	char *iflag = (char *)0;
	int rc = 0;

	while (start < argc && argv[start][0] == '-' && argv[start][1] != '\0') {
		if (argv[start][1] == 'n' && argv[start][2] == '\0' && start + 1 < argc) {
			char *np = argv[++start];
			int v = 0;
			while (*np >= '0' && *np <= '9') v = v*10 + (*np++ - '0');
			if (v > 0) nflag = v;
			start++;
		} else if (argv[start][1] == 'I' && argv[start][2] == '\0' && start + 1 < argc) {
			iflag = argv[++start];
			start++;
		} else {
			break;
		}
	}

	if (start >= argc) {
		fprintf(stderr, "usage: xargs [-n N] [-I REPLSTR] cmd [args...]\n");
		exit(1);
	}

	/* Read all of stdin into buf. */
	p = buf;
	while ((c = getchar()) != EOF) {
		if (p < buf + sizeof(buf) - 1)
			*p++ = (char)c;
	}
	*p = '\0';

	if (iflag) {
		/* One exec per input line, with REPLSTR substituted into the
		 * initial-args.  Lines are delimited by '\n'; trim. */
		static char slot[MAXBATCH][512];
		char line[4096];
		int li = 0;
		p = buf;
		while (*p) {
			li = 0;
			while (*p && *p != '\n' && li < (int)sizeof(line) - 1)
				line[li++] = *p++;
			while (*p == '\n') p++;
			line[li] = '\0';
			if (li == 0) continue;
			/* Build a fresh batch substituting line into each initial-arg. */
			nbatch = 0;
			for (i = start; i < argc && nbatch < MAXBATCH; i++) {
				batch[nbatch] = subst(argv[i], iflag, line,
				    slot[nbatch], sizeof(slot[nbatch]));
				nbatch++;
			}
			if (runbatch(batch, nbatch)) rc = 1;
		}
		exit(rc);
	}

	/* Seed batch with cmd + initial args. */
	base = 0;
	for (i = start; i < argc && base < MAXBATCH; i++)
		batch[base++] = argv[i];
	nbatch = base;

	tok = buf;
	while (*tok) {
		while (*tok && isspc(*tok)) tok++;
		if (!*tok) break;
		batch[nbatch++] = tok;
		while (*tok && !isspc(*tok)) tok++;
		if (*tok) *tok++ = '\0';
		/* If -n N is set, flush every N tokens (post-base). */
		if (nflag && (nbatch - base) >= nflag) {
			if (runbatch(batch, nbatch)) rc = 1;
			nbatch = base;
		}
		if (nbatch >= MAXBATCH) {
			if (runbatch(batch, nbatch)) rc = 1;
			nbatch = base;
		}
	}
	if (nbatch > base)
		if (runbatch(batch, nbatch)) rc = 1;
	exit(rc);
}
