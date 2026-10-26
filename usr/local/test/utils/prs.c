#include <stdio.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <sys/times.h>

unsigned short buf[4096];
volatile int spin;

int
main(void)
{
	struct stat sb;
	struct tms tb;
	int i, j, n;

	profil((short *)buf, sizeof buf, (int)main & ~0xfff, 0x8000);
	do {
		for (i = 0; i < 20; i++)
			stat("/usr/dict/words", &sb);
		for (j = 0; j < 20000; j++)
			spin++;
	} while (times(&tb), tb.tms_utime == 0 || tb.tms_stime == 0 ||
	    tb.tms_utime + tb.tms_stime < HZ/10);
	profil((short *)buf, sizeof buf, 0, 0);
	for (n = i = 0; i < 4096; i++)
		n += buf[i];
	times(&tb);
	printf("sys ticks %d utime %ld stime %ld\n", n,
	    (long)tb.tms_utime,
	    (long)tb.tms_stime);
	return 0;
}
