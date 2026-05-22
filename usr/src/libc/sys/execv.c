#define S_EXEC 11
int syscall3(int, int, int, int);
extern char **environ;
int
execv(char *path, char **argv)
{
	return(syscall3(S_EXEC, (int)path, (int)argv, (int)environ));
}
