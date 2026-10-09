/*	calloc - allocate and clear memory block
*/
#define CHARPERINT (sizeof(int)/sizeof(char))
#define NULL 0
#include <stdio.h>

char *
calloc(unsigned num, unsigned size)
{
	register char *mp;
	register int *q;
	register int m;

	num *= size;
	mp = malloc(num);
	if(mp == NULL)
		return(NULL);
	q = (int *) mp;
	m = (num+CHARPERINT-1)/CHARPERINT;
	while(--m>=0)
		*q++ = 0;
	return(mp);
}

void
cfree(char *p, unsigned num, unsigned size)
{
	(void)num;
	(void)size;
	free(p);
}
