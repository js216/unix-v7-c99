#define S_PAUSE 29
int syscall3(int, int, int, int);
int
pause(void)
{
	return(syscall3(S_PAUSE, 0, 0, 0));
}
