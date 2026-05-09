/* Ported from v7/usr/src/libc/gen/ttyslot.c.
 * K&R prototypes -> C99, register dropped, void cast on
 * deliberately-discarded close() return. */

#include "u.h"

#define	NULL	0

static char ttys[] = "/etc/ttys";

static char *
getttys(int f)
{
	static char line[32];
	char *lp;

	lp = line;
	for(;;) {
		if(read(f, lp, 1) != 1)
			return(NULL);
		if(*lp == '\n') {
			*lp = '\0';
			return(line + 2);
		}
		if(lp >= &line[32])
			return(line + 2);
		lp++;
	}
}

int
ttyslot(void)
{
	char *tp, *p;
	int s, tf;

	if((tp = ttyname(0)) == NULL
	    && (tp = ttyname(1)) == NULL
	    && (tp = ttyname(2)) == NULL)
		return(0);
	if((p = rindex(tp, '/')) == NULL)
		p = tp;
	else
		p++;
	if((tf = open(ttys, 0)) < 0)
		return(0);
	s = 0;
	while((tp = getttys(tf)) != 0) {
		s++;
		if(strcmp(p, tp) == 0) {
			(void)close(tf);
			return(s);
		}
	}
	(void)close(tf);
	return(0);
}
