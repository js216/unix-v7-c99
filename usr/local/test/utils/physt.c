#include <stdio.h>

extern int errno;
char dbuf[1024], bbuf[1024];

int
main(void)
{
	char sbuf[1024];
	int fd, bd, i, r1, r2;

	fd = open("/dev/rrk0", 0);
	bd = open("/dev/root", 0);
	lseek(bd, 2000L*512, 0);
	read(bd, bbuf, 512);
	lseek(fd, 2000L*512, 0);
	r1 = read(fd, dbuf, 512);
	lseek(fd, 2000L*512, 0);
	r2 = read(fd, sbuf, 512);
	for (i = 0; i < 512; i++)
		if (dbuf[i] != bbuf[i] || sbuf[i] != bbuf[i])
			break;
	printf("data %d stack %d %s\n", r1, r2, i == 512 ? "same" : "differ");
	errno = 0;
	r1 = read(fd, (char *)0x80000, 512);
	printf("gap: %d errno %d\n", r1, errno);
	errno = 0;
	r2 = read(fd, (char *)(((int)sbrk(0) + 511) & ~511) - 512, 1024);
	printf("across end of data: %d errno %d\n", r2, errno);
	return 0;
}
