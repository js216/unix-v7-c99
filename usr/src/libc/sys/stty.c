#define S_STTY 31
int syscall3(int, int, int, int);
int
stty(int fd, char *buf)
{
	return(syscall3(S_STTY, fd, (int)buf, 0));
}
