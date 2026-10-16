#include	<stdio.h>

int
getpw(int uid, char buf[])
{
	static FILE *pwf;
	register int n, c;
	register char *bp;

	if(pwf == 0)
		pwf = fopen("/etc/passwd", "r");
	if(pwf == NULL)
		return(1);
	rewind(pwf);

	for (;;) {
		bp = buf;
		while((c=getc(pwf)) != '\n') {
			if(c == EOF)
				return(1);
			if(bp < buf+BUFSIZ-1)
				*bp++ = c;
		}
		*bp++ = '\0';
		bp = buf;
		n = 3;
		while(--n)
		while((c = *bp++) != ':')
			if(c == '\0')
				goto next;
		while((c = *bp++) != ':') {
			if(c == '\0')
				goto next;
			if(c<'0' || c>'9')
				continue;
			if(n < 100000000)
				n = n*10+c-'0';
		}
		if(n == uid)
			return(0);
	next:	;
	}
}
