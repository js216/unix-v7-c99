/*	calloc - allocate and clear memory block
*/
#include <stdio.h>
#define CHARPERINT (sizeof(int)/sizeof(char))

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

