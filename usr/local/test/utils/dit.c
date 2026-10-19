#include <stdio.h>
#include <sys/param.h>
#include <sys/ino.h>

int
main(int argc, char **argv)
{
	struct dinode buf[INOPB], *dp;
	int f, i;

	if ((f = open(argv[1], argc > 3 ? 2 : 0)) < 0) {
		printf("cannot open %s\n", argv[1]);
		return 1;
	}
	i = atoi(argv[2]);
	dp = &buf[itoo(i)];
	lseek(f, itod(i)*(long)BSIZE, 0);
	read(f, (char *)buf, BSIZE);
	if (argc > 3) {
		sscanf(argv[3], "%lld", &dp->di_mtime);
		dp->di_atime = dp->di_mtime;
		lseek(f, itod(i)*(long)BSIZE, 0);
		write(f, (char *)buf, BSIZE);
	}
	printf("%lld %lld %lld\n", dp->di_atime, dp->di_mtime,
	    dp->di_ctime);
	return 0;
}
