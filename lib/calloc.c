/*	calloc - allocate and clear memory block
*/
#include <stdio.h>
#define CHARPERINT (sizeof(int)/sizeof(char))

char *
calloc(num, size)
unsigned num, size;
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

int
cfree(p, num, size)
char *p;
unsigned num, size;
{
	(void)num; (void)size;
	free(p);
	return(0);
}
