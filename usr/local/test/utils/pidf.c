#include <stdio.h>

int
main(int argc, char **argv)
{
	char b[16];
	int fd;

	(void)argc;
	sprintf(b, "%d\n", getpid());
	fd = creat(argv[1], 0644);
	write(fd, b, strlen(b));
	close(fd);
	execvp(argv[2], &argv[2]);
	printf("pidf: cannot execute %s\n", argv[2]);
	return 1;
}
