char *
memcpy(char *d, char *s, unsigned n)
{
	register char *p;
	register unsigned i;

	p = d;
	for (i = 0; i < n; i++)
		*p++ = *s++;
	return(d);
}

char *
memset(char *d, int c, unsigned n)
{
	register char *p;
	register unsigned i;

	p = d;
	for (i = 0; i < n; i++)
		*p++ = (char)c;
	return(d);
}
