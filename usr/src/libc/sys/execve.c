#define S_EXEC 11
int syscall3(int, int, int, int);
int
execve(char *path, char **argv, char **envp)
{
	return(syscall3(S_EXEC, (int)path, (int)argv, (int)envp));
}
