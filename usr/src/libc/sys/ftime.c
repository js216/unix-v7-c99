#include <sys/timeb.h>

#define S_FTIME 35
int syscall3(int, int, int, int);
int
ftime(struct timeb *gorpp)

{
	return(syscall3(S_FTIME, (int)gorpp, 0, 0));
}
