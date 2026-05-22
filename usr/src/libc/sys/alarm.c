#define S_ALARM 27
int syscall3(int, int, int, int);
int
alarm(int n)
{
	return(syscall3(S_ALARM, n, 0, 0));
}
