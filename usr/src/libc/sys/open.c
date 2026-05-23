#define S_OPEN 5
int syscall3(int, int, int, int);
int
open(char *path, int mode)
{
	return(syscall3(S_OPEN, (int)path, mode, 0));
}
