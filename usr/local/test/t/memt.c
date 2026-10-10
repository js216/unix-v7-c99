#include <stdio.h>

extern int errno;
char data[4096];

int
main(int argc, char **argv)
{
	char local[16];
	int fd, r;

	(void)argv;
	fd = open("/etc/passwd", 0);
	errno = 0;
	r = read(fd, (char *)0x80000, 16);
	printf("read gap: %d errno %d\n", r, errno);
	errno = 0;
	r = read(fd, (char *)0xfff00000, 16);
	printf("read kernel: %d errno %d\n", r, errno);
	errno = 0;
	r = write(1, (char *)0x80000, 16);
	printf("write gap: %d errno %d\n", r, errno);
	r = read(fd, local, 16);
	printf("read stack: %d\n", r);
	r = read(fd, data, 16);
	printf("read data: %d\n", r);
	if (argc > 1)
		*(int *)0x80000 = 1;
	return 0;
}
