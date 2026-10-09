char	*memcpy(char *d, char *s, unsigned n);
char	*memset(char *d, int c, unsigned n);
char *
memcpy(char *d, register char *s, register unsigned n)
{
	register char *p;

	p = d;
	while (n--)
		*p++ = *s++;
	return(d);
}

char *
memset(char *d, int c, register unsigned n)
{
	register char *p;

	p = d;
	while (n--)
		*p++ = c;
	return(d);
}
