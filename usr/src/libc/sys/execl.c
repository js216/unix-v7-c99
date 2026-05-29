#include <stdarg.h>
#define S_EXECE 59
int syscall3(int, int, int, int);
extern char **environ;
char *malloc(unsigned nbytes);
void free(char *ap);
int
execl(char *path, char *arg0, ...)
{
	va_list ap;
	char **argv, *arg;
	int i, n, r;

	n = 1;
	va_start(ap, arg0);
	while(va_arg(ap, char *) != 0)
		n++;
	va_end(ap);

	argv = (char **)malloc((unsigned)((n+1) * sizeof(char *)));
	if(argv == 0)
		return(-1);
	argv[0] = arg0;
	va_start(ap, arg0);
	for(i=1; i<n; i++) {
		arg = va_arg(ap, char *);
		argv[i] = arg;
	}
	va_end(ap);
	argv[n] = 0;
	r = syscall3(S_EXECE, (int)path, (int)argv, (int)environ);
	free((char *)argv);
	return(r);
}
