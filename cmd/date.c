/*
 * date : print date
 * date YYMMDDHHMM[.SS] : set date, if allowed
 * date -u ... : date in GMT
 */
#include <time.h>
#include <sys/types.h>
#include <sys/timeb.h>
#include <utmp.h>
#include <stdio.h>
long	timbuf;
char	*ap, *ep, *sp;
int	uflag;

int	gtime(void);
int	gp(int dfault);
void	exit(int n);
static	int	dmsize[12] =
{
	31,
	28,
	31,
	30,
	31,
	30,
	31,
	31,
	30,
	31,
	30,
	31
};

struct utmp wtmp[2] = { {"|", "", 0}, {"{", "", 0}};

int
main(int argc, char *argv[])
{
	register char *tzn;
	struct timeb info;
	int wf, rc;

	rc = 0;
	ftime(&info);
	if (argc>1 && argv[1][0]=='-' && argv[1][1]=='u') {
		argc--;
		argv++;
		uflag++;
	}
	/* POSIX "+FORMAT": print the current time using strftime-like
	 * codes.  Supports %Y %y %m %d %H %M %S %s %j %a %b %e %p plus
	 * literal % via %%.  v7 date had no such mode. */
	if (argc > 1 && argv[1][0] == '+') {
		struct tm *tp;
		char *f = argv[1] + 1;
		time(&timbuf);
		tp = uflag ? gmtime(&timbuf) : localtime(&timbuf);
		while (*f) {
			if (*f != '%') { putchar(*f++); continue; }
			f++;
			switch (*f) {
			case 'Y': printf("%04d", tp->tm_year + 1900); break;
			case 'y': printf("%02d", tp->tm_year % 100); break;
			case 'm': printf("%02d", tp->tm_mon + 1); break;
			case 'd': printf("%02d", tp->tm_mday); break;
			case 'e': printf("%2d",  tp->tm_mday); break;
			case 'H': printf("%02d", tp->tm_hour); break;
			case 'M': printf("%02d", tp->tm_min); break;
			case 'S': printf("%02d", tp->tm_sec); break;
			case 's': printf("%ld",  (long)timbuf); break;
			case 'j': printf("%03d", tp->tm_yday + 1); break;
			case 'p': fputs(tp->tm_hour < 12 ? "AM" : "PM", stdout); break;
			case 'a': {
				static char *days[] = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"};
				fputs(days[tp->tm_wday & 7], stdout); break;
			}
			case 'b': {
				static char *mons[] = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"};
				fputs(mons[tp->tm_mon % 12], stdout); break;
			}
			case '%': putchar('%'); break;
			case 'n': putchar('\n'); break;
			case 't': putchar('\t'); break;
			case '\0': putchar('%'); f--; break;
			default:  putchar('%'); putchar(*f); break;
			}
			if (*f) f++;
		}
		putchar('\n');
		exit(0);
	}
	if(argc > 1) {
		ap = argv[1];
		if (gtime()) {
			printf("date: bad conversion\n");
			exit(1);
		}
		/* convert to GMT assuming local time */
		if (uflag==0) {
			timbuf += (long)info.timezone*60;
			/* now fix up local daylight time */
			if(localtime(&timbuf)->tm_isdst)
				timbuf -= 60*60;
		}
		time(&wtmp[0].ut_time);
		if(stime(&timbuf) < 0) {
			rc++;
			printf("date: no permission\n");
		} else if ((wf = open("/usr/adm/wtmp", 1)) >= 0) {
			time(&wtmp[1].ut_time);
			lseek(wf, 0L, 2);
			write(wf, (char *)wtmp, sizeof(wtmp));
			close(wf);
		}
	}
	if (rc==0)
		time(&timbuf);
	if(uflag) {
		ap = asctime(gmtime(&timbuf));
		tzn = "GMT";
	} else {
		struct tm *tp;
		tp = localtime(&timbuf);
		ap = asctime(tp);
		tzn = timezone(info.timezone, tp->tm_isdst);
	}
	printf("%.20s", ap);
	if (tzn)
		printf("%s", tzn);
	printf("%s", ap+19);
	exit(rc);
}

int
gtime(void)
{
	register int i, year, month;
	int day, hour, mins, secs;
	struct tm *L;
	char x;

	ep=ap;
	while(*ep) ep++;
	sp=ap;
	while(sp<ep) {
		x = *sp;
		*sp++ = *--ep;
		*ep = x;
	}
	sp=ap;
	time(&timbuf);
	L=localtime(&timbuf);
	secs = gp(-1);
	if(*sp!='.') {
		mins=secs;
		secs=0;
	} else {sp++;
		mins = gp(-1);
	}
	hour = gp(-1);
	day = gp(L->tm_mday);
	month = gp(L->tm_mon+1);
	year = gp(L->tm_year);
	if(*sp)
		return(1);
	if( month<1 || month>12 ||
	    day<1 || day>31 ||
	    mins<0 || mins>59 ||
	    secs<0 || secs>59)
		return(1);
	if (hour==24) {
		hour=0; day++;
	}
	if (hour<0 || hour>23)
		return(1);
	timbuf = 0;
	year += 1900;
	for(i=1970; i<year; i++)
		timbuf += dysize(i);
	/* Leap year */
	if (dysize(year)==366 && month >= 3)
		timbuf++;
	while(--month)
		timbuf += dmsize[month-1];
	timbuf += day-1;
	timbuf = 24*timbuf + hour;
	timbuf = 60*timbuf + mins;
	timbuf = 60*timbuf + secs;
	return(0);

}

int
gp(int dfault)
{
	register int c, d;

	if(*sp==0)
		return(dfault);
	c = (*sp++)-'0';
	d = (*sp ? (*sp++)-'0' : 0);
	if(c<0 || c>9 || d<0 || d>9)
		return(-1);
	return(c+10*d);
}
