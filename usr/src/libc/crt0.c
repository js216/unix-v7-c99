#define	UARGV		0x0000f000

extern int main(int argc, char **argv);
extern void exit(int n);
char **environ;
int errno;
int *__errno(void) { return &errno; }

static char *argv[256];
static char *envp[256];
static char *emptyenv[] = { 0 };

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
		p++;
	}
	argv[argc] = 0;
	if(*p == 0) p++;
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
