#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/times.h>

unsigned short buf[4096];

int
main(void)
{
	struct stat sb;
	struct tms tb;
	int i, n;
	time_t t;

	profil((short *)buf, sizeof buf, 0, 0x8000);
	t = time(0);
	while (time(0) < t + 3)
		for (i = 0; i < 20; i++)
			stat("/usr/dict/words", &sb);
	profil((short *)buf, sizeof buf, 0, 0);
	for (n = i = 0; i < 4096; i++)
		n += buf[i];
	times(&tb);
	printf("sys ticks %d utime %ld stime %ld\n", n,
	    (long)tb.tms_utime,
	    (long)tb.tms_stime);
	return 0;
}
