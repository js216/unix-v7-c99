#define S_STIME 25
int syscall3(int, int, int, int);
int
stime(long *t)
{
	(void)syscall3(S_STIME, t ? (int)*t : 0, 0, 0);
	return(0);
}
