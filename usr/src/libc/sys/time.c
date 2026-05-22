#define S_TIME 13
int syscall3(int, int, int, int);
int
time(long *t)
{
	long now;
	now = (long)syscall3(S_TIME, 0, 0, 0);
	if(t)
		*t = now;
	return(now);
}
