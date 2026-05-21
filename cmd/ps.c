/*
 *	ps - process status
 *	examine and print certain things about processes
 */

#include <stdio.h>
#include <a.out.h>
/* core.h is not present in this port; inline the three macros it
 * defines (v7 PDP-11 values).  Feeds the user-text/data/stack
 * address-map setup in prcom(); only meaningful when the port can
 * read a user struct out of swap, which is best-effort. */
#define TXTRNDSIZ 8192L
#define stacktop(siz) (0x10000L)
#define stackbas(siz) (0x10000L-siz)
#include <sys/param.h>
/* v7 kernel-internal headers live under h/ in this port. */
#include "../h/proc.h"
/* sys/tty.h is not needed by this source (no struct tty fields are
 * touched here); a forward declaration is enough for the struct tty *
 * member referenced through u.u_ttyp. */
struct tty;
#include <sys/dir.h>
#include "../h/user.h"

struct nlist nl[] = {
	{ "_proc",    0, 0 },
	{ "_swapdev", 0, 0 },
	{ "_swplo",   0, 0 },
	{ "_pcomm",   0, 0 },
	{ "",         0, 0 },
};

static int cur_slot;	/* index of mproc within proc[]; passed to prcom indirectly */

struct	proc mproc;

struct	user u;
int	chkpid;
int	retcode=1;
int	lflg;
int	vflg;
int	kflg;
int	xflg;
char	*tptr;
long	lseek(int fd, long offset, int ptrname);
char	*gettty(void);
char	*getptr(char **adr);
/* strncmp() is declared in <stdio.h> with the standard prototype in
 * this port; the v7 K&R-era `char *strncmp()` line is dropped. */
int	getdev(void);
int	prcom(int puid);
int	getbyte(char *adr);
int	within(char *adr, long lbd, long ubd);
int	aflg;
int	mem;
int	swmem;
int	swap;
daddr_t	swplo;

int	ndev;
struct devl {
	char	dname[DIRSIZ];
	dev_t	dev;
} devl[256];

char	*coref;

int
main(int argc, char **argv)
{
	int i;
	char *ap;
	int uid, puid;

	if (argc>1) {
		ap = argv[1];
		while (*ap) switch (*ap++) {

		case 'v':
			vflg++;
			break;

		case 'a':
			aflg++;
			break;

		case 't':
			if(*ap)
				tptr = ap;
			aflg++;
			if (*tptr == '?')
				xflg++;
			goto bbreak;

		case 'x':
			xflg++;
			break;

		case '-':
			break;

		case 'l':
			lflg++;
			break;

		case 'k':
			kflg++;
			break;

		default:
			chkpid = atoi(ap-1);
			goto bbreak;
			break;
		}
	}

bbreak:
	if(chdir("/dev") < 0) {
		fprintf(stderr, "Can't change to /dev\n");
		exit(1);
	}
	nlist(argc>2? argv[2]:"/unix", nl);
	if (nl[0].n_type==0) {
		fprintf(stderr, "No namelist\n");
		exit(1);
	}
	coref = "/dev/mem";
	if(kflg)
		coref = "/usr/sys/core";
	if ((mem = open(coref, 0)) < 0) {
		fprintf(stderr, "No mem\n");
		exit(1);
	}
	swmem = open(coref, 0);
	/*
	 * read mem to find swap dev.
	 */
	lseek(mem, (long)nl[1].n_value, 0);
	read(mem, (char *)&nl[1].n_value, sizeof(nl[1].n_value));
	/*
	 * Find base of swap
	 */
	lseek(mem, (long)nl[2].n_value, 0);
	read(mem, (char *)&swplo, sizeof(swplo));
	/*
	 * Locate proc table
	 */
	lseek(mem, (long)nl[0].n_value, 0);
	getdev();
	uid = getuid();
	if (lflg)
	printf(" F S UID   PID  PPID CPU PRI NICE  ADDR  SZ  WCHAN TTY TIME CMD\n"); else
		if (chkpid==0) printf("   PID TTY TIME CMD\n");
	for (i=0; i<NPROC; i++) {
		read(mem, (char *)&mproc, sizeof mproc);
		if (mproc.p_stat==0)
			continue;
		if (mproc.p_pgrp==0 && xflg==0 && mproc.p_uid==0)
			continue;
		puid = mproc.p_uid;
		if ((uid != puid && aflg==0) ||
		    (chkpid!=0 && chkpid!=mproc.p_pid))
			continue;
		cur_slot = i;
		if(prcom(puid)) {
			printf("\n");
			retcode=0;
		}
	}
	exit(retcode);
}

int
getdev(void)
{
#include <sys/stat.h>
	register FILE *df;
	struct stat sbuf;
	struct direct dbuf;

	if ((df = fopen("/dev", "r")) == NULL) {
		fprintf(stderr, "Can't open /dev\n");
		exit(1);
	}
	ndev = 0;
	while (fread((char *)&dbuf, sizeof(dbuf), 1, df) == 1) {
		if(dbuf.d_ino == 0)
			continue;
		if(stat(dbuf.d_name, &sbuf) < 0)
			continue;
		if ((sbuf.st_mode&S_IFMT) != S_IFCHR)
			continue;
		strcpy(devl[ndev].dname, dbuf.d_name);
		devl[ndev].dev = sbuf.st_rdev;
		ndev++;
	}
	fclose(df);
	if ((swap = open("/dev/swap", 0)) < 0) {
		/* /dev/swap is absent on the ARM port; ps still prints proc
		 * table entries, but cannot reach swapped-out user pages. */
		swap = -1;
	}
	return(0);
}

long
round(long a, long b)
{
	long		w = ((a+b-1)/b)*b;

	return(w);
}

struct map {
	long	b1, e1; long f1;
	long	b2, e2; long f2;
};
struct map datmap;
int	file;
int
prcom(int puid)
{
	char abuf[512];
	long addr;
	register int *ip;
	register char *cp, *cp1;
	long tm;
	int c, nbad;
	register char *tp;
	long txtsiz, datsiz, stksiz;
	int septxt;
	int lw=(lflg?35:80);
	char **ap;
	(void)lw;

	if (mproc.p_flag&SLOAD) {
		addr = ctob((long)mproc.p_addr);
		file = swmem;
	} else {
		addr = (mproc.p_addr+swplo)<<9;
		file = swap;
	}
	lseek(file, addr, 0);
	if (read(file, (char *)&u, sizeof(u)) != sizeof(u))
		return(0);

	/* set up address maps for user pcs */
	txtsiz = ctob(u.u_tsize);
	datsiz = ctob(u.u_dsize);
	stksiz = ctob(u.u_ssize);
	septxt = u.u_sep;
	datmap.b1 = (septxt ? 0 : round(txtsiz,TXTRNDSIZ));
	datmap.e1 = datmap.b1+datsiz;
	datmap.f1 = ctob(USIZE)+addr;
	datmap.b2 = stackbas(stksiz);
	datmap.e2 = stacktop(stksiz);
	datmap.f2 = ctob(USIZE)+(datmap.e1-datmap.b1)+addr;

	tp = gettty();
	if (tptr && strncmp(tptr, tp, 2))
		return(0);
	if (lflg) {
		printf("%2o %c%4d", mproc.p_flag,
			"0SWRIZT"[(unsigned char)mproc.p_stat], puid);
	}
	printf("%6u", mproc.p_pid);
	if (lflg) {
		printf("%6u%4d%4d%5d%6o%4d", mproc.p_ppid, mproc.p_cpu&0377,
			mproc.p_pri,
			mproc.p_nice,
			mproc.p_addr, (mproc.p_size+7)>>3);
		if (mproc.p_wchan)
			printf("%7o", mproc.p_wchan);
		else
			printf("       ");
	}
	printf(" %-2.2s", tp);
	if (mproc.p_stat==SZOMB) {
		printf("  <defunct>");
		return(1);
	}
	tm = (u.u_utime + u.u_stime + 30)/60;
	printf(" %2ld:", tm/60);
	tm %= 60;
	printf(tm<10?"0%ld":"%ld", tm);
	if (vflg && lflg==0) {	/* 0 == old tflg (print long times) */
		tm = (u.u_cstime + 30)/60;
		printf(" %2ld:", tm/60);
		tm %= 60;
		printf(tm<10?"0%ld":"%ld", tm);
		tm = (u.u_cutime + 30)/60;
		printf(" %2ld:", tm/60);
		tm %= 60;
		printf(tm<10?"0%ld":"%ld", tm);
	}
	/* For parked processes the live USERBASE window doesn't cover their
	 * UARGV buffer, so fall back to the per-slot pcomm[] table the
	 * kernel populates at exec() time.  The running ps has its own
	 * argv in UARGV and prefers that. */
	{
		char nb[16];
		lseek(swmem, (long)nl[3].n_value + (long)cur_slot * 16, 0);
		if (read(swmem, nb, 16) == 16) {
			nb[15] = '\0';
			if (nb[0] && mproc.p_size == 0) {
				printf(" %.15s", nb);
				return(1);
			}
		}
	}
	if (mproc.p_pid == 0) {
		printf(" swapper");
		return(1);
	}
	/* In real v7, p_addr*64 / p_size*64 describe the swap-clicks layout
	 * of a process's user struct + text/data/stack image, and the scan
	 * below walks the top of the user stack (where exec() laid out
	 * argv[]) byte by byte through a saved struct user{} address map.
	 *
	 * This port has no swap and only one live user image at a time
	 * (USERBASE..USERBASE+USERSIZE), with argv kept as a single
	 * NUL-terminated, space-separated buffer at the fixed user VA
	 * UARGV (see arch/armboot.c::kexec2 / kspawn).  arch/u_bridge.c::
	 * v7_proc_set_current() steers p_addr/p_size for the currently
	 * running proc at UARGV/UARGLEN respectively, so the lseek+read
	 * below lands directly on that buffer; every other proc gets
	 * p_size==0 and we just print pid/tty/time with no command.
	 *
	 * The "sh special" indirect-argv walk and the backward stack scan
	 * from the original v7 source are dropped: our argv buffer is a
	 * single contiguous C string, not a v7 user-stack layout. */
	if (mproc.p_size == 0)
		return(1);
	/* Read from the START of UARGV (where kargs lays out NUL-separated
	 * argv strings).  Original v7 read at addr+size-512 because v7 placed
	 * argv at the top of the user stack; in this port the buffer base is
	 * UARGV itself. */
	lseek(file, addr, 0);
	if (read(file, abuf, sizeof(abuf)) != sizeof(abuf))
		return(1);
	abuf[sizeof(abuf)-1] = '\0';
	if (abuf[0] == '\0')
		return(1);
	/* argv args are NUL-separated; replace NULs between non-empty strings
	 * with spaces so the whole command line prints as one row.  Stop at
	 * the argv terminator (two NULs in a row -> empty-string sentinel). */
	{
		int z;
		for (z = 0; z < (int)sizeof(abuf) - 1; z++) {
			if (abuf[z] == '\0' && abuf[z+1] == '\0') { abuf[z] = '\0'; break; }
			if (abuf[z] == '\0') abuf[z] = ' ';
		}
	}
	/* Sanitize non-printables and trim trailing space so the line stays
	 * one row even if the in-kernel buffer had stale tail bytes. */
	for (cp = abuf; *cp; cp++) {
		c = *cp & 0177;
		if (c < ' ' || c > '~')
			*cp = '?';
	}
	while (cp > abuf && cp[-1] == ' ')
		*--cp = '\0';
	/* ip/cp1/ap/nbad/getbyte/within/getptr are inherited from the
	 * historical v7 argv-scan and become unused once we just print the
	 * raw argbuf; cast them to void so -Wunused stays quiet without
	 * disturbing the surrounding declarations. */
	(void)ap; (void)cp1; (void)ip; (void)nbad;
	printf(lflg?" %.30s":" %.60s", abuf);
	return(1);
}

char *
gettty(void)
{
	register int i;
	register char *p;

	if (u.u_ttyp==0)
		return("?");
	for (i=0; i<ndev; i++) {
		if (devl[i].dev == u.u_ttyd) {
			p = devl[i].dname;
			if (p[0]=='t' && p[1]=='t' && p[2]=='y')
				p += 3;
			return(p);
		}
	}
	return("?");
}

char *
getptr(char **adr)
{
	char *ptr;
	register char *p, *pa;
	register unsigned int i;

	ptr = 0;
	pa = (char *)adr;
	p = (char *)&ptr;
	for (i=0; i<sizeof(ptr); i++)
		*p++ = getbyte(pa++);
	return(ptr);
}

int
getbyte(char *adr)
{
	register struct map *amap = &datmap;
	char b;
	long saddr;

	if(!within(adr, amap->b1, amap->e1)) {
		if(within(adr, amap->b2, amap->e2)) {
			saddr = (unsigned)adr + amap->f2 - amap->b2;
		} else
			return(0);
	} else
		saddr = (unsigned)adr + amap->f1 - amap->b1;
	if(lseek(file, saddr, 0)==-1
		   || read(file, &b, 1)<1) {
		return(0);
	}
	return((unsigned)b);
}


int
within(char *adr, long lbd, long ubd)
{
	return((unsigned long)adr>=(unsigned long)lbd && (unsigned long)adr<(unsigned long)ubd);
}
