#include	<stdio.h>

char *
fgets(char *s, int n, register FILE *iop)
{
	register int c;
	register char *cs;

	cs = s;
	while (--n>0 && (c = getc(iop))>=0) {
		*cs++ = c;
		if (c=='\n')
			break;
	}
	if (c<0 && cs==s)
		return(NULL);
	*cs++ = '\0';
	return(s);
}
