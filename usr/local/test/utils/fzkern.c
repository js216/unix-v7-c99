/*
 * fzkern: audit the kernel's books, run when the fuzzers have stopped.
 * Every page of core must be free on the page stack, a u-area, or a
 * page of the map of an image or a text in core, once; the u-area of
 * process 0 is the kernel's own, below them.  Every block
 * of swap must be free in the swap map, or hold the image of a process
 * swapped out or a text, once, and every page table must be free or a
 * process's.  A text's counts must be those of the processes which use
 * it, a file's count that of the processes which have it open, and an
 * inode's count that of the files, directories, texts, and mounts that
 * hold it.  Something which leaks without a panic shows here.  A
 * process in the middle of a system call can hold what the books do
 * not show yet, so a difference counts only if it stays for five tries
 * a second apart.  Prints each difference of the last try and exits 1;
 * prints "fzkern ok" otherwise.
 *	fzkern -w pid	watch the swap while process pid lives
 */

#include <stdio.h>
#include <a.out.h>
#include <sys/param.h>
#include <sys/dir.h>
#include "h/proc.h"
#include "h/user.h"
#include "h/text.h"
#include "h/file.h"
#include "h/inode.h"
#define	mount	kmount	/* not the system call */
#include "h/mount.h"
#undef	mount
#include "h/map.h"

#define	PGSIZE	4096
#define	NPM	(PGSIZE/(int)sizeof(int))
#define	MAXPG	(1<<18)		/* 1 GB of core */
#define	MAXSWAP	(1<<21)		/* 1 GB of swap */

struct nlist nl[] = {
#define	X_PROC	0
	{ "_proc", 0, 0 },
#define	X_TEXT	1
	{ "_text", 0, 0 },
#define	X_FILE	2
	{ "_file", 0, 0 },
#define	X_INODE	3
	{ "_inode", 0, 0 },
#define	X_MOUNT	4
	{ "_mount", 0, 0 },
#define	X_SWAPMAP 5
	{ "_swapmap", 0, 0 },
#define	X_PTMAP	6
	{ "_ptmap", 0, 0 },
#define	X_NPGFREE 7
	{ "_npgfree", 0, 0 },
#define	X_PGSTK	8
	{ "_pgstk", 0, 0 },
#define	X_MAXMEM 9
	{ "_maxmem", 0, 0 },
#define	X_NSWAP	10
	{ "_nswap", 0, 0 },
#define	X_SWPLO	11
	{ "_swplo", 0, 0 },
#define	X_CORETOP 12
	{ "_coretop", 0, 0 },
#define	X_ROOTDIR 13
	{ "_rootdir", 0, 0 },
#define	X_ACCTP	14
	{ "_acctp", 0, 0 },
	{ "", 0, 0 },
};

struct	proc	xproc[NPROC];
struct	text	xtext[NTEXT];
struct	file	xfile[NFILE];
struct	inode	xinode[NINODE];
struct	kmount	xmount[NMOUNT];
struct	map	xswapmap[SMAPSIZ], xptmap[PMAPSIZ];
struct	user	xu;
int	npgfree, pgstk[MAXPG], maxmem, nswap;
unsigned	ktop;
daddr_t	swplo;
struct	inode	*rootdir, *acctp;
unsigned char	pgbit[MAXPG/8], swbit[MAXSWAP/8], ptbit[NPTAB/8 + 1];
int	lo, hi;			/* the pages of core */
int	pgowner[MAXPG];		/* who has each page, for the report */
int	nfref[NFILE], niref[NINODE], nxref[NTEXT], nxcref[NTEXT];
int	kmem, mem, swap, nbad, report;

static void
bad(char *fmt, int a, int b, int c)
{
	nbad++;
	if(report) {
		printf("FAIL fzkern: ");
		printf(fmt, a, b, c);
		printf("\n");
	}
}

static void
clear(void *p, int n)
{
	register char *c;

	for(c = p; n > 0; n--)
		*c++ = 0;
}

static int
kread(unsigned long addr, void *p, int n)
{
	return(lseek(kmem, (long)addr, 0) != -1 && read(kmem, (char *)p, n) == n);
}

static int
pread(int pg, int off, void *p, int n)
{
	return(lseek(mem, (long)ptob((unsigned)pg) + off, 0) != -1 &&
	    read(mem, (char *)p, n) == n);
}

/*
 * Page pg belongs to owner w, a process slot or NPROC+text slot
 */
static void
page(int pg, int w)
{
	if(pg < lo || pg >= hi) {
		bad("page 0x%x of %d is not core", pg, w, 0);
		return;
	}
	if(pgbit[(pg-lo)/8] & 1<<(pg-lo)%8) {
		bad("page 0x%x is %d's and %d's", pg, pgowner[pg-lo], w);
		return;
	}
	pgbit[(pg-lo)/8] |= 1<<(pg-lo)%8;
	pgowner[pg-lo] = w;
}

/*
 * The pages of a map of n entries
 */
static void
map(int m, int n, int w)
{
	static int root[NPM], list[NPM];
	int i, j;

	if(n <= 0) {
		if(m != 0)
			bad("%d has a map 0x%x of no entries", w, m, 0);
		return;
	}
	if(n > MAXPG) {
		bad("%d has a map of %d entries", w, n, 0);
		return;
	}
	page(m, w);
	if(!pread(m, 0, root, PGSIZE)) {
		bad("%d's map 0x%x cannot be read", w, m, 0);
		return;
	}
	for(i = 0; i*NPM < n; i++) {
		page(root[i], w);
		if(!pread(root[i], 0, list, PGSIZE)) {
			bad("%d's list page 0x%x cannot be read", w, root[i], 0);
			return;
		}
		for(j = 0; j < NPM && i*NPM + j < n; j++)
			page(list[j], w);
	}
}

static void
swblk(int a, int n, int w)
{
	int i;

	if(a < 1 || n < 0 || a + n > nswap + 1) {
		bad("swap %d+%d of %d is not swap", a, n, w);
		return;
	}
	for(i = a; i < a + n; i++) {
		if(swbit[i/8] & 1<<i%8) {
			bad("swap block %d of %d is used twice", i, w, 0);
			return;
		}
		swbit[i/8] |= 1<<i%8;
	}
}

static int
count(unsigned char *bit, int n)
{
	int i, c;

	for(c = 0, i = 0; i < n; i++)
		if(bit[i/8] & 1<<i%8)
			c++;
	return(c);
}

/*
 * The slot of a pointer into a table, or -1
 */
static int
slot(void *p, int x, int size, int n)
{
	unsigned long a;

	a = (unsigned long)p;
	if(a < nl[x].n_value || a >= nl[x].n_value + (unsigned long)size*n ||
	    (a - nl[x].n_value) % size)
		return(-1);
	return((a - nl[x].n_value) / size);
}

static void
iref(struct inode *ip, char *what, int w)
{
	int i;

	if(ip == NULL)
		return;
	if((i = slot(ip, X_INODE, sizeof(struct inode), NINODE)) < 0) {
		if(report)
			printf("FAIL fzkern: the %s of %d is not an inode\n",
			    what, w);
		nbad++;
	} else
		niref[i]++;
}

static void
audit(void)
{
	register struct proc *p;
	register struct text *xp;
	int i, j, live, a;

	nbad = 0;
	clear(pgbit, sizeof(pgbit));
	clear(swbit, sizeof(swbit));
	clear(ptbit, sizeof(ptbit));
	clear(nfref, sizeof(nfref));
	clear(niref, sizeof(niref));
	clear(nxref, sizeof(nxref));
	clear(nxcref, sizeof(nxcref));
	if(!kread(nl[X_NPGFREE].n_value, &npgfree, sizeof(npgfree)) ||
	    !kread(nl[X_PGSTK].n_value, &a, sizeof(a)) ||
	    npgfree < 0 || npgfree > maxmem ||
	    !kread(a, pgstk, npgfree*sizeof(int)) ||
	    !kread(nl[X_PROC].n_value, xproc, sizeof(xproc)) ||
	    !kread(nl[X_TEXT].n_value, xtext, sizeof(xtext)) ||
	    !kread(nl[X_FILE].n_value, xfile, sizeof(xfile)) ||
	    !kread(nl[X_INODE].n_value, xinode, sizeof(xinode)) ||
	    !kread(nl[X_MOUNT].n_value, xmount, sizeof(xmount)) ||
	    !kread(nl[X_SWAPMAP].n_value, xswapmap, sizeof(xswapmap)) ||
	    !kread(nl[X_PTMAP].n_value, xptmap, sizeof(xptmap)) ||
	    !kread(nl[X_ROOTDIR].n_value, &rootdir, sizeof(rootdir)) ||
	    !kread(nl[X_ACCTP].n_value, &acctp, sizeof(acctp))) {
		bad("cannot read the kernel", 0, 0, 0);
		return;
	}

	/* core */
	for(i = 0; i < npgfree; i++)
		page(pgstk[i], -1);
	for(p = xproc; p < &xproc[NPROC]; p++) {
		if(p->p_stat == 0 || p->p_stat == SZOMB)
			continue;
		i = p - xproc;
		if(p->p_flag & (SLOCK|SSWAP))
			bad("%d is locked, flags 0%o", i, p->p_flag, 0);
		if(p->p_size < USIZE)
			bad("%d has %d pages", i, p->p_size, 0);
		if(p->p_flag & SLOAD) {
			for(j = 0; j < USIZE && i != 0; j++)
				page(p->p_addr + j, i);
			map(p->p_map, p->p_size - USIZE, i);
		} else {
			if(p->p_map != 0 || p->p_nptab != 0)
				bad("%d is out but has map 0x%x, %d page tables",
				    i, p->p_map, p->p_nptab);
			swblk(p->p_addr, ptod(p->p_size), i);
		}
	}
	for(xp = xtext; xp < &xtext[NTEXT]; xp++) {
		if(xp->x_iptr == NULL)
			continue;
		i = xp - xtext;
		if(xp->x_flag & (XLOCK|XLOAD|XWANT))
			bad("text %d is locked, flags 0%o", i, xp->x_flag, 0);
		if((xp->x_map != 0) != (xp->x_ccount != 0))
			bad("text %d has map 0x%x, %d in core", i, xp->x_map,
			    xp->x_ccount);
		if(xp->x_map)
			map(xp->x_map, xp->x_size, NPROC + i);
		swblk(xp->x_daddr, ptod(xp->x_size), NPROC + i);
	}
	if((i = count(pgbit, hi - lo)) != maxmem)
		bad("%d pages of core are lost, of %d", maxmem - i, maxmem, 0);

	/* swap */
	for(i = 0; i < SMAPSIZ && xswapmap[i].m_size; i++)
		swblk(xswapmap[i].m_addr, xswapmap[i].m_size, -1);
	if((i = count(swbit, nswap + 1)) != nswap)
		bad("%d blocks of swap are lost, of %d", nswap - i, nswap, 0);

	/* page tables, numbered from the lowest free */
	a = xptmap[0].m_addr;
	for(p = xproc; p < &xproc[NPROC]; p++)
		if(p->p_nptab && p->p_ptab < a)
			a = p->p_ptab;
	for(i = 0; i < PMAPSIZ && xptmap[i].m_size; i++)
		for(j = 0; j < xptmap[i].m_size; j++)
			if(xptmap[i].m_addr + j - a < 0 ||
			    xptmap[i].m_addr + j - a >= NPTAB)
				bad("page table 0x%x is out of range",
				    xptmap[i].m_addr + j, 0, 0);
			else
				ptbit[(xptmap[i].m_addr+j-a)/8] |=
				    1<<(xptmap[i].m_addr+j-a)%8;
	for(p = xproc; p < &xproc[NPROC]; p++)
		for(j = 0; j < p->p_nptab; j++) {
			int t = p->p_ptab + j - a;

			if(t < 0 || t >= NPTAB || (ptbit[t/8] & 1<<t%8)) {
				bad("page table 0x%x of %d is out or used twice",
				    p->p_ptab + j, (int)(p - xproc), 0);
				break;
			}
			ptbit[t/8] |= 1<<t%8;
		}
	if((i = count(ptbit, NPTAB)) != NPTAB)
		bad("%d page tables are lost, of %d", NPTAB - i, NPTAB, 0);

	/* references held by processes */
	for(p = xproc; p < &xproc[NPROC]; p++) {
		if(p->p_stat == 0 || p->p_stat == SZOMB)
			continue;
		i = p - xproc;
		if(p->p_textp) {
			if((j = slot(p->p_textp, X_TEXT, sizeof(struct text),
			    NTEXT)) < 0) {
				bad("%d's text is not a text", i, 0, 0);
				continue;
			}
			nxref[j]++;
			if(p->p_flag & SLOAD)
				nxcref[j]++;
		}
		if(p->p_flag & SLOAD)
			live = lseek(mem, (long)ptob((unsigned)p->p_addr), 0)
			    != -1 && read(mem, (char *)&xu, sizeof(xu)) == sizeof(xu);
		else
			live = lseek(swap, ((long)p->p_addr + swplo)*512, 0)
			    != -1 && read(swap, (char *)&xu, sizeof(xu)) == sizeof(xu);
		if(!live) {
			bad("the u-area of %d cannot be read", i, 0, 0);
			continue;
		}
		iref(xu.u_cdir, "directory", i);
		iref(xu.u_rdir, "root", i);
		for(j = 0; j < NOFILE; j++) {
			if(xu.u_ofile[j] == NULL)
				continue;
			if((a = slot(xu.u_ofile[j], X_FILE, sizeof(struct file),
			    NFILE)) < 0)
				bad("file %d of %d is not a file", j, i, 0);
			else
				nfref[a]++;
		}
	}
	for(i = 0; i < NTEXT; i++) {
		xp = &xtext[i];
		if(xp->x_iptr == NULL) {
			if(nxref[i])
				bad("free text %d has %d users", i, nxref[i], 0);
			continue;
		}
		iref(xp->x_iptr, "prototype", NPROC + i);
		if(xp->x_count != nxref[i])
			bad("text %d counts %d users but has %d", i,
			    xp->x_count, nxref[i]);
		if(xp->x_ccount != nxcref[i])
			bad("text %d counts %d in core but has %d", i,
			    xp->x_ccount, nxcref[i]);
	}
	for(i = 0; i < NFILE; i++) {
		if(xfile[i].f_count != nfref[i])
			bad("file %d counts %d but has %d", i, xfile[i].f_count,
			    nfref[i]);
		if(xfile[i].f_count)
			iref(xfile[i].f_inode, "inode", -2);
	}
	for(i = 0; i < NMOUNT; i++)
		if(xmount[i].m_bufp)
			iref(xmount[i].m_inodp, "mounted-on directory", -3);
	iref(rootdir, "root directory", -4);
	iref(acctp, "accounting file", -5);
	for(i = 0; i < NINODE; i++)
		if(xinode[i].i_count != niref[i])
			bad("inode %d counts %d but has %d", xinode[i].i_number,
			    xinode[i].i_count, niref[i]);
}

/*
 * Watch, while process pid lives, the most blocks of swap which held
 * images of processes at once, and the most processes swapped out; a
 * failure if there were none, since then the swapper went untried
 */
static void
watch(int pid)
{
	int i, n, used, most, out, mostout;

	most = mostout = 0;
	while(kill(pid, 0) == 0) {
		if(!kread(nl[X_PROC].n_value, xproc, sizeof(xproc)))
			break;
		used = out = 0;
		for(i = 0; i < NPROC; i++)
			if(xproc[i].p_stat && xproc[i].p_stat != SZOMB &&
			    (xproc[i].p_flag & SLOAD) == 0) {
				out++;
				used += ptod(xproc[i].p_size);
			}
		if(used > most)
			most = used;
		if(out > mostout)
			mostout = out;
		sleep(1);
	}
	n = most/2048;
	if(mostout == 0)
		printf("FAIL fzkern: nothing was swapped out\n");
	else
		printf("fzkern: at most %d MB of %d processes swapped out\n",
		    n, mostout);
}

int
main(int argc, char **argv)
{
	int t;

	nlist("/unix", nl);
	for(t = 0; nl[t].n_name[0]; t++)
		if(nl[t].n_value == 0) {
			printf("FAIL fzkern: no %s in /unix\n", nl[t].n_name);
			exit(1);
		}
	if((kmem = open("/dev/kmem", 0)) < 0 || (mem = open("/dev/mem", 0)) < 0 ||
	    (swap = open("/dev/swap", 0)) < 0) {
		printf("FAIL fzkern: cannot open the memory and swap\n");
		exit(1);
	}
	if(!kread(nl[X_MAXMEM].n_value, &maxmem, sizeof(maxmem)) ||
	    !kread(nl[X_NSWAP].n_value, &nswap, sizeof(nswap)) ||
	    !kread(nl[X_SWPLO].n_value, &swplo, sizeof(swplo)) ||
	    !kread(nl[X_CORETOP].n_value, &ktop, sizeof(ktop))) {
		printf("FAIL fzkern: cannot read the kernel\n");
		exit(1);
	}
	hi = btop(ktop);
	lo = hi - maxmem;
	if(maxmem <= 0 || maxmem > MAXPG || nswap <= 0 || nswap >= MAXSWAP) {
		printf("FAIL fzkern: %d pages of core, %d of swap\n", maxmem,
		    nswap);
		exit(1);
	}
	if(argc == 3 && strcmp(argv[1], "-w") == 0) {
		watch(atoi(argv[2]));
		exit(0);
	}
	for(t = 0; t < 5; t++) {
		report = t == 4;
		audit();
		if(nbad == 0) {
			printf("fzkern ok\n");
			exit(0);
		}
		sleep(1);
	}
	exit(1);
}
