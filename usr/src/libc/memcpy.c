char *
memcpy(d, s, n)
char *d;
register char *s;
register unsigned n;
{
	register char *p;

	p = d;
	while (n--)
		*p++ = *s++;
	return(d);
}

char *
memset(d, c, n)
char *d;
int c;
register unsigned n;
{
	register char *p;

	p = d;
	while (n--)
		*p++ = c;
	return(d);
}
