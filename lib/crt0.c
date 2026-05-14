/*
 * crt0.c -- userland entry point.  _start (in crt0.s) calls _startc,
 * which parses argv out of the spawn page at UARGV and dispatches to
 * main(), then exits via libc's exit() so stdio buffers are flushed.
 */

#define	UARGV		0x0000f000
#define	UARGLEN		512

extern int main(int argc, char **argv);
extern void exit(int n);

static char *argv[32];

static int
getargs(char **argv, int maxarg)
{
	char *p;
	int argc;

	argc = 0;
	p = (char *)UARGV;
	while(*p && argc < maxarg-1) {
		while(*p == ' ' || *p == '\t')
			p++;
		if(*p == 0)
			break;
		argv[argc++] = p;
		while(*p && *p != ' ' && *p != '\t')
			p++;
		if(*p)
			*p++ = 0;
	}
	argv[argc] = 0;
	return(argc);
}

void
_startc(void)
{
	int argc;

	argc = getargs(argv, 32);
	exit(main(argc, argv));
}
