char end[1];
static char *curbrk = (char *)0x00050000;

char *
sbrk(int n)
{
	char *old;
	old = curbrk;
	curbrk += n;
	return(old);
}

int
brk(char *p)
{
	curbrk = p;
	return(0);
}
