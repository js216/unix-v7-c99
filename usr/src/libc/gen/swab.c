#include <stdio.h>
/*
 * Swap bytes in 16-bit [half-]words
 * for going between the 11 and the interdata
 */

void
swab(char *from, char *to, register int n)
{
	register short *pf = (short *)from, *pt = (short *)to;

	n /= 2;
	while (--n >= 0) {
		*pt++ = (*pf << 8) + ((*pf >> 8) & 0377);
		pf++;
	}
}
