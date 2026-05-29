extern int main(int argc, char **argv);
extern void exit(int n);
char **environ;
int errno;
int *__errno(void) { return &errno; }

/*
 * Entry from crt0.s with r0 = sp, which points at the argument frame the
 * kernel built on exec: { argc, argv[0..argc-1], 0, envp[0..], 0 }.
 */
void
_startc(int *frame)
{
	int argc = frame[0];
	char **argv = (char **)&frame[1];

	environ = (char **)&frame[argc + 2];
	exit(main(argc, argv));
}
