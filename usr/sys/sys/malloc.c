#include "../h/param.h"
#include "../h/systm.h"
#include "../h/map.h"
#include "../h/seg.h"

/*
 * Allocate 'size' units from the given
 * map. Return the base of the allocated
 * space.
 * In a map, the addresses are increasing and the
 * list is terminated by a 0 size.
 * The swap map unit is 512 bytes; the page table map
 * unit is 4096 bytes.
 * Algorithm is first-fit.
 */
int
malloc(struct map *mp, int size)
{
	register unsigned int a;
	register struct map *bp;

	for (bp=mp; bp->m_size; bp++) {
		if (bp->m_size >= size) {
			a = bp->m_addr;
			bp->m_addr += size;
			if ((bp->m_size -= size) == 0) {
				do {
					bp++;
					(bp-1)->m_addr = bp->m_addr;
				} while (((bp-1)->m_size = bp->m_size));
			}
			return(a);
		}
	}
	return(0);
}

/*
 * Free the previously allocated space a
 * of size units into the specified map.
 * Sort a into map and combine on
 * one or both ends if possible.
 */
void
mfree(struct map *mp, int size, register int a)
{
	register struct map *bp;
	register unsigned int t;

	for (bp = mp; bp->m_addr<=a && bp->m_size!=0; bp++);
	if (bp>mp && (bp-1)->m_addr+(bp-1)->m_size == a) {
		(bp-1)->m_size += size;
		if (a+size == bp->m_addr) {
			(bp-1)->m_size += bp->m_size;
			while (bp->m_size) {
				bp++;
				(bp-1)->m_addr = bp->m_addr;
				(bp-1)->m_size = bp->m_size;
			}
		}
	} else {
		if (a+size == bp->m_addr && bp->m_size) {
			bp->m_addr -= size;
			bp->m_size += size;
		} else if (size) {
			do {
				t = bp->m_addr;
				bp->m_addr = a;
				a = t;
				t = bp->m_size;
				bp->m_size = size;
				bp++;
			} while ((size = t));
		}
	}
}

/*
 * Core is allocated a page at a time, from a stack of the numbers
 * of the free pages, which startup fills.
 */
int	*pgstk;
int	npgfree;

int
pgalloc(void)
{
	if (npgfree == 0)
		return(0);
	return(pgstk[--npgfree]);
}

void
pgfree(int pg)
{
	pgstk[npgfree++] = pg;
	if (runin) {
		runin = 0;
		wakeup((caddr_t)&runin);
	}
}

/*
 * A page map lists the pages of a process's image, or of a text, in
 * order: a root page holds the numbers of list pages, and each list
 * page the numbers of NPM pages.  A map of n entries has its root,
 * and list pages for entries 0 to n-1; the map of no entries is 0.
 */
#define	NPM	(PGSIZE/(int)sizeof(int))

int *
mapent(int map, int i)
{
	return((int *)PGADDR(((int *)PGADDR(map))[i/NPM]) + i%NPM);
}

/*
 * The number of pages that growing a map from n0 to n1 entries takes,
 * the pages of the entries and of the map itself
 */
int
mapneed(int n0, int n1)
{
	if (n1 <= n0)
		return(0);
	return(n1-n0 + (n0 == 0) + (n1+NPM-1)/NPM - (n0+NPM-1)/NPM);
}

/*
 * Grow the map *mp from n0 to n1 entries, each a new page;
 * 0 if there is not enough core, which the caller checks first
 */
int
mapalloc(int *mp, int n0, int n1)
{
	register int i, pg;

	if (mapneed(n0, n1) > npgfree)
		return(0);
	if (n1 > n0 && n0 == 0) {
		*mp = pgalloc();
		clearseg(*mp);
	}
	for (i = n0; i < n1; i++) {
		if (i%NPM == 0) {
			pg = pgalloc();
			((int *)PGADDR(*mp))[i/NPM] = pg;
		}
		*mapent(*mp, i) = pgalloc();
	}
	return(1);
}

/*
 * Shrink the map *mp from n1 to n0 entries, freeing their pages
 */
void
mapfree(int *mp, int n0, int n1)
{
	register int i;

	for (i = n1-1; i >= n0; i--) {
		pgfree(*mapent(*mp, i));
		if (i%NPM == 0)
			pgfree(((int *)PGADDR(*mp))[i/NPM]);
	}
	if (n0 == 0 && n1 > 0) {
		pgfree(*mp);
		*mp = 0;
	}
}

/*
 * Turn the entries from a to c of map around, so that those from b
 * to c come first; it moves pages within an image without copying
 */
static void
maprev(int map, int a, int c)
{
	register int t, *p, *q;

	while (a < --c) {
		p = mapent(map, a++);
		q = mapent(map, c);
		t = *p;
		*p = *q;
		*q = t;
	}
}

void
maprot(int map, int a, int b, int c)
{
	maprev(map, a, b);
	maprev(map, b, c);
	maprev(map, a, c);
}
