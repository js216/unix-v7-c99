/*
 * Swap bytes in 16-bit [half-]words for going between the 11
 * and the interdata.
 *
 * Ported from v7/usr/src/libc/gen/swab.c.  K&R prototype -> C99,
 * register dropped, void return.
 */

void
swab(short *pf, short *pt, int n)
{

	n /= 2;
	while(--n >= 0) {
		*pt++ = (*pf << 8) + ((*pf >> 8) & 0377);
		pf++;
	}
}
