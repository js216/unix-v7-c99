#define S_EXECE 59
int syscall3(int, int, int, int);
int
execve(char *path, char **argv, char **envp)
{
	return(syscall3(S_EXECE, (int)path, (int)argv, (int)envp));
}
