/* /usr/lib/calendar produces an egrep -f file
   that will select today's and tomorrow's
   calendar entries, with special weekend provisions

   used by calendar command
*/
#include <time.h>
#include <stdio.h>

#define DAY (3600*24L)

char *month[] = {
	"[Jj]an",
	"[Ff]eb",
	"[Mm]ar",
	"[Aa]pr",
	"[Mm]ay",
	"[Jj]un",
	"[Jj]ul",
	"[Aa]ug",
	"[Ss]ep",
	"[Oo]ct",
	"[Nn]ov",
	"[Dd]ec"
};
struct tm *localtime();

void tprint(long t);
int time(long *t);

void
tprint(t)
long t;
{
	struct tm *tm;
	tm = localtime(&t);
	printf("(^|[ (,;])((%s[^ ]* *|%d/)0*%d)([^0123456789]|$)\n",
		month[tm->tm_mon], tm->tm_mon + 1, tm->tm_mday);
}

int
main()
{
	long t;
	time(&t);
	tprint(t);
	switch(localtime(&t)->tm_wday) {
	case 5:
		t += DAY;
		tprint(t);
		/* FALLTHROUGH */
	case 6:
		t += DAY;
		tprint(t);
		/* FALLTHROUGH */
	default:
		t += DAY;
		tprint(t);
	}
}
