extern char end[];
static char *curbrk;
int syscall3(int, int, int, int);
int brk(char *);
#define	S_BREAK	17


char *
sbrk(int n)
{
	char *old;
	if(curbrk == 0)
		curbrk = end;
	old = curbrk;
	if(brk(curbrk + n) < 0)
		return((char *)-1);
	return(old);
}


int
brk(char *p)
{
	if(syscall3(S_BREAK, (int)p, 0, 0) < 0)
		return(-1);
	curbrk = p;
	return(0);
}
