/*
 * Userland bump allocator -- the v7 libc/gen/malloc.c uses brk(2),
 * which the C99/Armv7 kernel does not yet service.  This is the same
 * bump scheme u.h's previous static-inline malloc used: each call
 * advances a private brk pointer; free is a no-op.
 */

static char *brkp = (char *)0x00060000;

char *
malloc(unsigned n)
{
	unsigned *p;

	n = (n + 3) & ~3;
	p = (unsigned *)brkp;
	*p++ = n;
	brkp += n + sizeof(unsigned);
	return((char *)p);
}

void
free(char *p)
{

	(void)p;
}

char *
realloc(char *p, unsigned n)
{
	char *q;
	unsigned i, old;

	if(p == 0)
		return(malloc(n));
	old = ((unsigned *)p)[-1];
	q = malloc(n);
	if(q == 0)
		return(0);
	if(old > n)
		old = n;
	for(i=0; i<old; i++)
		q[i] = p[i];
	return(q);
}
