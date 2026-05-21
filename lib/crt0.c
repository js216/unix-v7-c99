/*
 * crt0.c -- userland entry point.  _start (in crt0.s) calls _startc,
 * which parses argv out of the exec-staged page at UARGV and dispatches
 * to main(), then exits via libc's exit() so stdio buffers are flushed.
 */

#define	UARGV		0x0000f000

extern int main(int argc, char **argv);
extern void exit(int n);
extern char **environ;

/* 256 entries each: v7's original crt0 hardcoded 32 and that limit
 * was visible from userspace -- `ls /tmp/f*` against 100 files only
 * passed 30 names through.  256 is still bounded but plenty for sh
 * glob expansions of typical directory sizes. */
static char *argv[256];
static char *envp[256];
static char *emptyenv[] = { 0 };

/* arch/armboot.c::kargs lays out argv as NUL-separated strings, an
 * empty-string sentinel, then envp the same way.  We parse both. */
static char *argv_end;

static int
getargs(char **argv, int maxarg)
{
	char *p;
	int argc;

	argc = 0;
	p = (char *)UARGV;
	while(*p && argc < maxarg-1) {
		argv[argc++] = p;
		while(*p)
			p++;
		p++;	/* past arg's terminating NUL */
	}
	argv[argc] = 0;
	if(*p == 0) p++;	/* past the empty-string sentinel */
	argv_end = p;
	return(argc);
}

static void
getenvp(char **envp, int maxenv)
{
	char *p = argv_end;
	int envc;

	envc = 0;
	while(*p && envc < maxenv-1) {
		envp[envc++] = p;
		while(*p)
			p++;
		p++;
	}
	envp[envc] = 0;
	environ = envc ? envp : emptyenv;
}

void
_startc(void)
{
	int argc;

	argc = getargs(argv, 256);
	getenvp(envp, 256);
	exit(main(argc, argv));
}
