#define S_DUP 41
int syscall3(int, int, int, int);
int
dup(int a, int b)
{
	if(a & 0100)
		return(syscall3(S_DUP, a, b, 0));
	return(syscall3(S_DUP, a, -1, 0));
}
