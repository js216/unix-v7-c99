#define S_GTTY 32
int syscall3(int, int, int, int);
int
gtty(int fd, char *buf)
{
	return(syscall3(S_GTTY, fd, (int)buf, 0));
}
