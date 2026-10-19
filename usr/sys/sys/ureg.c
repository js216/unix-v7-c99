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
 * Build the page tables of the current
 * process from the software prototype.
 */
static void
ptbuild(register struct proc *p)
{
	register unsigned long long *t;
	register unsigned i, a;
	unsigned long long *l1;
	unsigned n, b, n2, n3lo, n3hi;
	int taddr, daddr;

	taddr = daddr = p->p_addr;
	if (p->p_textp != NULL)
		taddr = p->p_textp->x_caddr;
	n = u.u_ptsize + u.u_pdsize;
	n2 = (n+PTPGB-1) / PTPGB;
	n3lo = (n+NPTE-1) / NPTE;
	n3hi = (u.u_pssize+NPTE-1) / NPTE;
	n = n2 + n3lo + (n3hi != 0) + n3hi;
	if(n == 0)
		return;
	if((a = malloc(ptmap, n)) == 0) {
		printf("out of page tables\n");
		psignal(p, SIGKIL);
		return;
	}
	p->p_ptab = a;
	p->p_nptab = n;
	t = (unsigned long long *)PGADDR(a);
	for(i = 0; i < NPTE*n; i++)
		t[i] = 0;
	l1 = &l1tab[4*(p-proc)];
	a = ptob(a);
	for(i = 0; i < n2; i++, a += PGSIZE)
		l1[i] = a | PTE_TAB;
	for(i = 0; i < n3lo; i++, a += PGSIZE)
		t[i] = a | PTE_TAB;
	t += NPTE*n2;
	b = ptob(taddr);
	for(i = 0; i < u.u_ptsize; i++, b += PGSIZE)
		*t++ = b | PGUSER | u.u_pxrw;
	b = ptob(daddr) + ptob(USIZE);
	for(i = 0; i < u.u_pdsize; i++, b += PGSIZE)
		*t++ = b | PGUSER | RW;
	if(n3hi == 0)
		return;
	t = (unsigned long long *)PGADDR(p->p_ptab) + NPTE*(n2+n3lo);
	l1[2] = a | PTE_TAB;
	for(i = 0; i < n3hi; i++)
		t[NPTE-n3hi+i] = (a += PGSIZE) | PTE_TAB;
	t += NPTE + NPTE*n3hi - u.u_pssize;
	for(i = 0; i < u.u_pssize; i++, b += PGSIZE)
		*t++ = b | PGUSER | RW;
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
 * Load the user hardware segmentation
 * registers from the software prototype.
 * The software registers must have
 * been setup prior by estabur.
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
 * Set up software prototype segmentation
 * registers to implement the 3 pseudo
 * text,data,stack segment sizes passed
 * as arguments.
 * The argument sep specifies if the
 * text and data+stack segments are to
 * be separated.
 * The last argument determines whether the text
 * segment is read-write or read-only.
 */
int
estabur(unsigned nt, unsigned nd, unsigned ns, int sep, int xrw)
{

	if(sep)
		goto err;
	if(nt+nd > 2*PTPGB || ns > PTPGB)
		goto err;
	if((int)(nt+nd+ns+USIZE) > maxmem)
		goto err;
	u.u_ptsize = nt;
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
