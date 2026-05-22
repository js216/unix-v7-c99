#include <stdarg.h>
#define S_EXEC 11
int syscall3(int, int, int, int);
extern char **environ;
int
execl(char *path, char *arg0, ...)
{
	va_list ap;
	char *argv[16];
	int i;

	argv[0] = arg0;
	va_start(ap, arg0);
	for(i=1; i<15; i++)
		if((argv[i] = va_arg(ap, char *)) == 0)
			break;
	argv[i] = 0;
	va_end(ap);
	return(syscall3(S_EXEC, (int)path, (int)argv, (int)environ));
}
