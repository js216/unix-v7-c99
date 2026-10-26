#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/text.h"
#include "../h/map.h"
#include "../h/seg.h"

unsigned long long *l1tab;
unsigned l1pa;

/*
 * A range of user pages: the first page, the number of pages, the
 * page map which lists them from its entry first, or none and the
 * first page itself, and the access bits
 */
struct urange {
	unsigned va, n;
	int map, first;
	unsigned ap;
};

/*
 * The page of entry i of a range, or 0 if the map does not hold it
 * yet, while expand has still to add it
 */
static unsigned
upage(register struct urange *rp, unsigned i, int nent)
{
	if(rp->map == 0)
		return(rp->first + i);
	if(rp->first + (int)i >= nent)
		return(0);
	return(*mapent(rp->map, rp->first + i));
}

/*
 * Build the page tables of the current process from the prototype:
 * one second-level table for each gigabyte, and one third-level table
 * for each 2 MB block, that the text, data, stack, and signal
 * trampoline touch.
 */
static void
ptbuild(register struct proc *p)
{
	struct urange r[4], t;
	register struct urange *rp;
	register unsigned pg;
	unsigned long long *l1, *l2, *l3;
	unsigned nr, n, a, gb, blk, pa;
	int i, j, nent[4];

	nr = 0;
	if(u.u_ptsize && p->p_textp != NULL) {
		rp = &r[nr++];
		rp->va = u.u_ptstart;
		rp->n = u.u_ptsize;
		rp->map = p->p_textp->x_map;
		rp->first = 0;
		rp->ap = u.u_pxrw;
		nent[nr-1] = p->p_textp->x_size;
	}
	if(u.u_pdsize) {
		rp = &r[nr++];
		rp->va = u.u_pdstart;
		rp->n = u.u_pdsize;
		rp->map = p->p_map;
		rp->first = 0;
		rp->ap = RW;
		nent[nr-1] = p->p_size - USIZE;
	}
	if(u.u_pssize) {
		rp = &r[nr++];
		rp->va = btop(USRSIZE) - u.u_pssize;
		rp->n = u.u_pssize;
		rp->map = p->p_map;
		rp->first = u.u_pdsize;
		rp->ap = RW;
		nent[nr-1] = p->p_size - USIZE;
	}
	rp = &r[nr++];
	rp->va = btop(SIGTRAMP);
	rp->n = 1;
	rp->map = 0;
	rp->first = sigpage;
	rp->ap = RO;
	nent[nr-1] = 1;
	for(i = 1; i < (int)nr; i++)
		for(j = i; j > 0 && r[j-1].va > r[j].va; j--) {
			t = r[j];
			r[j] = r[j-1];
			r[j-1] = t;
			a = nent[j];
			nent[j] = nent[j-1];
			nent[j-1] = a;
		}

	n = 0;
	gb = blk = ~0U;
	for(rp = r; rp < &r[nr]; rp++)
		for(pg = rp->va; pg < rp->va+rp->n; pg = (pg|(NPTE-1)) + 1) {
			if(pg>>(L1SHIFT-PGSHIFT) != gb) {
				gb = pg>>(L1SHIFT-PGSHIFT);
				n++;
			}
			if(pg>>(BLKSHIFT-PGSHIFT) != blk) {
				blk = pg>>(BLKSHIFT-PGSHIFT);
				n++;
			}
		}
	if((a = malloc(ptmap, n)) == 0) {
		printf("out of page tables\n");
		psignal(p, SIGKIL);
		return;
	}
	p->p_ptab = a;
	p->p_nptab = n;
	l3 = (unsigned long long *)PGADDR(a);
	for(i = 0; i < (int)(NPTE*n); i++)
		l3[i] = 0;

	l1 = &l1tab[4*(p-proc)];
	l2 = l3 = NULL;
	gb = blk = ~0U;
	for(rp = r; rp < &r[nr]; rp++)
		for(pg = rp->va; pg < rp->va+rp->n; pg++) {
			if((pa = upage(rp, pg - rp->va, nent[rp-r])) == 0)
				continue;
			if(pg>>(L1SHIFT-PGSHIFT) != gb) {
				gb = pg>>(L1SHIFT-PGSHIFT);
				l1[gb] = ptob(a) | PTE_TAB;
				l2 = (unsigned long long *)PGADDR(a++);
			}
			if(pg>>(BLKSHIFT-PGSHIFT) != blk) {
				blk = pg>>(BLKSHIFT-PGSHIFT);
				l2[blk & (NPTE-1)] = ptob(a) | PTE_TAB;
				l3 = (unsigned long long *)PGADDR(a++);
			}
			l3[pg & (NPTE-1)] = ptob(pa) | PGUSER | rp->ap;
		}
}

/*
 * Release the page tables of a process.
 */
void
ptfree(register struct proc *p)
{
	register unsigned long long *l1;

	if(p->p_nptab) {
		mfree(ptmap, p->p_nptab, p->p_ptab);
		p->p_nptab = 0;
	}
	l1 = &l1tab[4*(p-proc)];
	l1[0] = l1[1] = l1[2] = 0;
}

/*
 * Point the processor at the current process's page tables, building
 * them first if estabur has discarded them.
 */
void
sureg(void)
{
	register struct proc *p;

	p = u.u_procp;
	if(p->p_nptab == 0)
		ptbuild(p);
	ttbset(l1pa + 32*(p-proc));
}

/*
 * Nonzero if the n pages from page a and the m pages from page b
 * have none in common
 */
static int
apart(unsigned a, unsigned n, unsigned b, unsigned m)
{
	return(n == 0 || m == 0 || a+n <= b || b+m <= a);
}

/*
 * Set up the prototype of the user's address space: nt pages of text
 * from page ts, nd pages of data from page ds, and ns pages of stack
 * ending at USRSIZE.  The segments must lie within the user's space,
 * apart from each other and from the signal trampoline, and the image
 * must fit in memory.  xrw is the access to the text, RO or RW.
 */
int
estabur(unsigned ts, unsigned nt, unsigned ds, unsigned nd, unsigned ns,
    int xrw)
{
	register unsigned top, ss, tr;

	top = btop(USRSIZE);
	if(nt > top || ts > top-nt || nd > top || ds > top-nd || ns > top)
		goto err;
	ss = top - ns;
	tr = btop(SIGTRAMP);
	if(!apart(ts, nt, ds, nd) || !apart(ts, nt, ss, ns) ||
	    !apart(ds, nd, ss, ns) || !apart(ts, nt, tr, 1) ||
	    !apart(ds, nd, tr, 1) || !apart(ss, ns, tr, 1))
		goto err;
	if(nt+nd+ns+USIZE > maxmem)
		goto err;
	u.u_ptstart = ts;
	u.u_ptsize = nt;
	u.u_pdstart = ds;
	u.u_pdsize = nd;
	u.u_pssize = ns;
	u.u_pxrw = xrw;
	ptfree(u.u_procp);
	sureg();
	return(0);

err:
	u.u_error = ENOMEM;
	return(-1);
}
