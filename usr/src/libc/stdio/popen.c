#define S_EXIT 1
#define S_FORK 2
#define S_CLOSE 6
#define S_EXEC 11
#define S_DUP 41
#define S_PIPE 42
#define S_WAIT 7
int syscall3(int, int, int, int);
typedef struct { int fd; } FILE;

FILE *
popen(char *cmd, char *mode)
{
	static FILE f;
	int fd[2];
	char *argv[4];

	if(*mode != 'r')
		return(0);
	if(syscall3(S_PIPE, (int)fd, 0, 0) < 0)
		return(0);
	if(syscall3(S_FORK, 0, 0, 0) == 0) {
		(void)syscall3(S_CLOSE, fd[0], 0, 0);
		(void)syscall3(S_DUP, fd[1], 1, 0);
		argv[0] = "sh";
		argv[1] = "-c";
		argv[2] = cmd;
		argv[3] = 0;
		(void)syscall3(S_EXEC, (int)"/bin/sh", (int)argv, 0);
		(void)syscall3(S_EXIT, 1, 0, 0);
	}
	(void)syscall3(S_CLOSE, fd[1], 0, 0);
	f.fd = fd[0];
	return(&f);
}

int
pclose(FILE *f)
{
	(void)syscall3(S_CLOSE, f->fd, 0, 0);
	return(syscall3(S_WAIT, 0, 0, 0));
}
