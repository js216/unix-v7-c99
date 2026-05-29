#define S_EXECE 59
int syscall3(int, int, int, int);
extern char **environ;
int
execv(char *path, char **argv)
{
	return(syscall3(S_EXECE, (int)path, (int)argv, (int)environ));
}
