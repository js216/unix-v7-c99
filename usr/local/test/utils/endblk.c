#include <stdio.h>

/*
 * endblk dev n: write a marked block at block n of dev, read it back,
 * and try to read the block after it, which lies past the end.
 */
int
main(int argc, char **argv)
{
	char b[512];
	long n;
	int fd, i;

	(void)argc;
	n = atol(argv[2]);
	fd = open(argv[1], 2);
	for (i = 0; i < 512; i++)
		b[i] = 0;
	sprintf(b, "end of disk\n");
	lseek(fd, n*512, 0);
	printf("write %d\n", write(fd, b, 512));
	for (i = 0; i < 512; i++)
		b[i] = 'x';
	lseek(fd, n*512, 0);
	printf("read %d %s", read(fd, b, 512), b);
	for (i = 12; i < 512 && b[i] == 0; i++)
		;
	printf("zeros %d\n", i == 512);
	printf("past %d\n", read(fd, b, 512));
	return 0;
}
