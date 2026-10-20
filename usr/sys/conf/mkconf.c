#include "../h/param.h"
#include <stdio.h>
#include <string.h>

void	puke(char **s);
int	input(void), equal(char *a, char *b), badline(char *line);

#define CHAR	01
#define BLOCK	02
#define INTR	04
#define EVEN	010
#define KL	020
#define ROOT	040
#define	SWAP	0100
#define	PIPE	0200

char	*btab[] =
{
	"rk",
	"rp",
	"rf",
	"tm",
	"tc",
	"hs",
	"hp",
	"ht",
	"rl",
	0
};
char	*ctab[] =
{
	"console",
	"pc",
	"lp",
	"dc",
	"dh",
	"dp",
	"dj",
	"dn",
	"mem",
	"rk",
	"rf",
	"rp",
	"tm",
	"hs",
	"hp",
	"ht",
	"du",
	"tty",
	"rl",
	0
};
struct tab
{
	char	*name;
	int	count;
	int	address;
	int	key;
	char	*codea;
	char	*codeb;
	char	*codec;
	char	*coded;
	char	*codee;
	char	*codef;
	char	*codeg;
} table[] =
{
	{
	"console",
	-1, 60, CHAR+INTR+KL,
	"	klin; br4\n	klou; br4\n",
	".globl	_klrint\nklin:	jsr	r0,call; jmp _klrint\n",
	".globl	_klxint\nklou:	jsr	r0,call; jmp _klxint\n",
	"",
	"	klopen, klclose, klread, klwrite, klioctl, nulltty, 0,",
	"",
	"",
	},

	{
	"mem",
	-1, 300, CHAR,
	"",
	"",
	"",
	"",
	"nulldev, nulldev, mmread, mmwrite, noioctl, nulltty, 0, ",
	"",
	"",
	},

	{
	"pc",
	0, 70, CHAR+INTR,
	"	pcin; br4\n	pcou; br4\n",
	".globl	_pcrint\npcin:	jsr	r0,call; jmp _pcrint\n",
	".globl	_pcpint\npcou:	jsr	r0,call; jmp _pcpint\n",
	"",
	"	pcopen, pcclose, pcread, pcwrite, nodev, nulldev, 0, ",
	"",
	"int	pcopen(), pcclose(), pcread(), pcwrite();",
	},

	{
	"clock",
	-2, 100, INTR,
	"	kwlp; br6\n",
	".globl	_clock\n",
	"kwlp:	jsr	r0,call; jmp _clock\n",
	"",
	"",
	"",
	"",
	},

	{
	"parity",
	-1, 114, INTR,
	"	trap; br7+7.		/ 11/70 parity\n",
	"",
	"",
	"",
	"",
	"",
	"",
	},

/*
 * 110 unused
 * 114 memory parity
 * 120 XY plotter
 * 124 DR11-B
 * 130 AD01 & RL01
*/

	{
	"rl",
	0, 130, BLOCK+CHAR+INTR,
	"	rlio; br5\n",
	".globl	_rlintr\n",
	"rlio:	jsr	r0,call; jmp _rlintr\n",
	"	nulldev, nulldev, rlstrategy, &rltab,",
	"	rlopen, rlclose, rlread, rlwrite, nodev, nulldev, 0,",
	"int	rlstrategy();\nstruct	buf	rltab;",
	"int	rlopen(), rlclose(), rlread(), rlwrite();",
	},

/*
 * 134 AFC11
 * 140 AA11
 * 144 AA11
 * 150-174 unused
 */

	{
	"lp",
	0, 200, CHAR+INTR,
	"	lpou; br4\n",
	"",
	".globl	_lpint\nlpou:	jsr	r0,call; jmp _lpint\n",
	"",
	"	lpopen, lpclose, nodev, lpwrite, nodev, nulldev, 0,",
	"",
	"int	lpopen(), lpclose(), lpwrite();",
	},

	{
	"rf",
	0, 204, BLOCK+CHAR+INTR,
	"	rfio; br5\n",
	".globl	_rfintr\n",
	"rfio:	jsr	r0,call; jmp _rfintr\n",
	"	nulldev, nulldev, rfstrategy, &rftab, ",
	"	nulldev, nulldev, rfread, rfwrite, nodev, nulldev, 0,",
	"int	rfstrategy();\nstruct	buf	rftab;",
	"int	rfread(), rfwrite();",
	},

	{
	"hs",
	0, 204, BLOCK+CHAR+INTR,
	"	hsio; br5\n",
	".globl	_hsintr\n",
	"hsio:	jsr	r0,call; jmp _hsintr\n",
	"	nulldev, nulldev, hsstrategy, &hstab, ",
	"	nulldev, nulldev, hsread, hswrite, nodev, nulldev, 0,",
	"int	hsstrategy();\nstruct	buf	hstab;",
	"int	hsread(), hswrite();",
	},

/*
 * 210 RC
 */

	{
	"tc",
	0, 214, BLOCK+INTR,
	"	tcio; br6\n",
	".globl	_tcintr\n",
	"tcio:	jsr	r0,call; jmp _tcintr\n",
	"	nulldev, tcclose, tcstrategy, &tctab,",
	"",
	"int	tcstrategy(), tcclose();\nstruct	buf	tctab;",
	"",
	},

	{
	"rk",
	0, 220, BLOCK+CHAR+INTR,
	"	rkio; br5\n",
	".globl	_rkintr\n",
	"rkio:	jsr	r0,call; jmp _rkintr\n",
	"	nulldev, nulldev, rkstrategy, &rktab,",
	"nulldev, nulldev, rkread, rkwrite, noioctl, nulltty, 0,",
	"extern struct	buf	rktab;",
	"",
	},

	{
	"tm",
	0, 224, BLOCK+CHAR+INTR,
	"	tmio; br5\n",
	".globl	_tmintr\n",
	"tmio:	jsr	r0,call; jmp _tmintr\n",
	"	tmopen, tmclose, tmstrategy, &tmtab, ",
	"	tmopen, tmclose, tmread, tmwrite, nodev, nulldev, 0,",
	"int	tmopen(), tmclose(), tmstrategy();\n"
	"struct	buf	tmtab;",
	"int	tmread(), tmwrite();",
	},

	{
	"ht",
	0, 224, BLOCK+CHAR+INTR,
	"	htio; br5\n",
	".globl	_htintr\n",
	"htio:	jsr	r0,call; jmp _htintr\n",
	"	htopen, htclose, htstrategy, &httab,",
	"	htopen, htclose, htread, htwrite, nodev, nulldev, 0,",
	"int	htopen(), htclose(), htstrategy();\n"
	"struct	buf	httab;",
	"int	htread(), htwrite();",
	},

	{
	"cr",
	0, 230, CHAR+INTR,
	"	crin; br6\n",
	"",
	".globl	_crint\ncrin:	jsr	r0,call; jmp _crint\n",
	"",
	"	cropen, crclose, crread, nodev, nodev, nulldev, 0,",
	"",
	"int	cropen(), crclose(), crread();",
	},

/*
 * 234 UDC11
 */

	{
	"rp",
	0, 254, BLOCK+CHAR+INTR,
	"	rpio; br5\n",
	".globl	_rpintr\n",
	"rpio:	jsr	r0,call; jmp _rpintr\n",
	"	nulldev, nulldev, rpstrategy, &rptab,",
	"	nulldev, nulldev, rpread, rpwrite, nodev, nulldev, 0,",
	"int	rpstrategy();\nstruct	buf	rptab;",
	"int	rpread(), rpwrite();",
	},

	{
	"hp",
	0, 254, BLOCK+CHAR+INTR,
	"	hpio; br5\n",
	".globl	_hpintr\n",
	"hpio:	jsr	r0,call; jmp _hpintr\n",
	"	nulldev, nulldev, hpstrategy, &hptab,",
	"	nulldev, nulldev, hpread, hpwrite, nodev, nulldev, 0,",
	"int	hpstrategy();\nstruct	buf	hptab;",
	"int	hpread(), hpwrite();",
	},

/*
 * 260 TA11
 * 264-274 unused
 */

	{
	"dc",
	0, 308, CHAR+INTR,
	"	dcin; br5+%d.\n	dcou; br5+%d.\n",
	".globl	_dcrint\ndcin:	jsr	r0,call; jmp _dcrint\n",
	".globl	_dcxint\ndcou:	jsr	r0,call; jmp _dcxint\n",
	"",
	"dcopen, dcclose, dcread, dcwrite, dcioctl, nulldev, dc11,",
	"",
	"int	dcopen(), dcclose(), dcread(), dcwrite(), dcioctl();\n"
	"struct	tty	dc11[];",
	},

	{
	"kl",
	0, 308, INTR+KL,
	"	klin; br4+%d.\n	klou; br4+%d.\n",
	"",
	"",
	"",
	"",
	"",
	"",
	},

	{
	"dp",
	0, 308, CHAR+INTR,
	"	dpin; br6+%d.\n	dpou; br6+%d.\n",
	".globl	_dprint\ndpin:	jsr	r0,call; jmp _dprint\n",
	".globl	_dpxint\ndpou:	jsr	r0,call; jmp _dpxint\n",
	"",
	"	dpopen, dpclose, dpread, dpwrite, nodev, nulldev, 0,",
	"",
	"int	dpopen(), dpclose(), dpread(), dpwrite();",
	},

/*
 * DM11-A
 */

	{
	"dn",
	0, 304, CHAR+INTR,
	"	dnou; br5+%d.\n",
	"",
	".globl	_dnint\ndnou:	jsr	r0,call; jmp _dnint\n",
	"",
	"	dnopen, dnclose, nodev, dnwrite, nodev, nulldev, 0,",
	"",
	"int	dnopen(), dnclose(), dnwrite();",
	},

	{
	"dhdm",
	0, 304, INTR,
	"	dmin; br4+%d.\n",
	"",
	".globl	_dmint\ndmin:	jsr	r0,call; jmp _dmint\n",
	"",
	"",
	"",
	"",
	},

/*
 * DR11-A+
 * DR11-C+
 * PA611+
 * PA611+
 * DT11+
 * DX11+
 */

	{
	"dl",
	0, 308, INTR+KL,
	"	klin; br4+%d.\n	klou; br4+%d.\n",
	"",
	"",
	"",
	"",
	"",
	"",
	},

/*
 * DJ11
 */

	{
	"dh",
	0, 308, CHAR+INTR+EVEN,
	"	dhin; br5+%d.\n	dhou; br5+%d.\n",
	".globl	_dhrint\ndhin:	jsr	r0,call; jmp _dhrint\n",
	".globl	_dhxint\ndhou:	jsr	r0,call; jmp _dhxint\n",
	"",
	"dhopen, dhclose, dhread, dhwrite, dhioctl, dhstop, dh11,",
	"",
	"int	dhopen(), dhclose(), dhread(), dhwrite(), dhioctl(), "
	"dhstop();\nstruct	tty	dh11[];",
	},

/*
 * GT40
 * LPS+
 * DQ11
 * KW11-W
 */

	{
	"du",
	0, 308, CHAR+INTR,
	"	duin; br6+%d.\n	duou; br6+%d.\n",
	".globl	_durint\nduin:	jsr	r0,call; jmp _durint\n",
	".globl	_duxint\nduou:	jsr	r0,call; jmp _duxint\n",
	"",
	"	duopen, duclose, duread, duwrite, nodev, nulldev, 0,",
	"",
	"int	duopen(), duclose(), duread(), duwrite();",
	},

	{
	"tty",
	1, 0, CHAR,
	"",
	"",
	"",
	"",
	"syopen, nulldev, syread, sywrite, sysioctl, nulltty, 0,",
	"",
	"",
	},

	{0}
};

char	*stre[] =
{
	"#include \"../h/param.h\"",
	"#include \"../h/systm.h\"",
	"#include \"../h/buf.h\"",
	"#include \"../h/tty.h\"",
	"#include \"../h/conf.h\"",
	"#include \"../h/proc.h\"",
	"#include \"../h/text.h\"",
	"#include \"../h/dir.h\"",
	"#include \"../h/user.h\"",
	"#include \"../h/file.h\"",
	"#include \"../h/inode.h\"",
	"#include \"../h/acct.h\"",
	"",
	"#include \"../h/seg.h\"",
	"#include \"../h/map.h\"",
	"#include \"../h/mount.h\"",
	"#include \"../h/callo.h\"",
	0
};

char	*stre1[] =
{
	"struct	bdevsw	bdevsw[] =",
	"{",
	0,
};

char	*strf[] =
{
	"	{0}",
	"};",
	"",
	0,
};

char	*strf1[] =
{
	"",
	"struct	cdevsw	cdevsw[] =",
	"{",
	0,
};

char	strg[] =
{
"	{0}\n\
};\n\
int	rootdev	= makedev(%d, %d);\n\
int	swapdev	= makedev(%d, %d);\n\
int	pipedev = makedev(%d, %d);\n\
int	nldisp = %d;\n\
daddr_t	swplo	= %ld;\n\
int	nswap	= %d;\n\
"};

char	strg1[] =
{
"	\n\
struct	buf	buf[NBUF];\n\
struct	file	file[NFILE];\n\
struct	inode	inode[NINODE];\n"
};

char	strg2[] =
{
"struct	proc	proc[NPROC];\n\
struct	text	text[NTEXT];\n\
struct	buf	bfreelist;\n\
struct	acct	acctbuf;\n\
struct	inode	*acctp;\n"
};

char	strg3[] =
{
"int	buffers[NBUF+1][(BSIZE+BSLOP+63)/64*16];\n\
struct	map	coremap[CMAPSIZ];\n\
struct	map	swapmap[SMAPSIZ];\n\
struct	map	ptmap[PMAPSIZ];\n\
struct	mount	mount[NMOUNT];\n\
struct	callo	callout[NCALL];\n\
struct	cblock	cfree[NCLIST];\n"
};

char	*strh[] =
{
	"	{0}",
	"};",
	"",
	0
};

char	*stri[] =
{
	"int	pkopen(), pkclose(), pkread(), pkwrite(), pkioctl(), "
	"pkrint(), pkxint();",
	0
};

char	*strj[] =
{
	"struct	linesw	linesw[] =",
	"{",
	"\t{ttyopen, nulltty, ttread, ttwrite, nolioctl, ttyinput,",
	"\t    0, 0, ttstart, 0}, /* 0 */",
	0
};

char	*strk[] =
{
	"\t{pkopen, pkclose, pkread, pkwrite, pkioctl, pkrint, pkxint,",
	"\t    0, 0, 0}, /* 1 */",
	0
};

int	pack;
int	mpx;
int	rootmaj = -1;
int	rootmin;
int	swapmaj = -1;
int	swapmin;
int	pipemaj = -1;
int	pipemin;
long	swplo	= 4000;
int	nswap = 872;
int	pack;
int	nldisp = 1;
int	ddr;
unsigned long	ramv, ramb, ramn, tabv, tabb, tabn, coret, gicd, gicc;
#define	NMAP	9
unsigned long	mapv[NMAP], mapb[NMAP], mape[NMAP];
char	mapa[NMAP][100];
int	nmap;

int
main(void)
{
	register struct tab *p;
	register char *q;
	int i;
	char *x;

	while(input());

/*
 * pass1 -- create linker script
 */
	freopen("unix.ld", "w", stdout);
	printf("MEMORY\n{\n");
	printf("\tRAM (rwx) : ORIGIN = 0x%lx, LENGTH = 0x%lx\n", ramv,
	    ramn);
	if (tabn)
		printf("\tTAB (rwx) : ORIGIN = 0x%lx, LENGTH = 0x%lx\n",
		    tabv, tabn);
	printf("}\nu = 0x%X;\nENTRY(start)\n", UBASE);
	printf("start = _start - 0x%lx;\nSECTIONS\n{\n", ramv-ramb);
	printf("\t.text : AT(ADDR(.text) - 0x%lx) "
	    "{ *(.text*) } > RAM\n", ramv-ramb);
	printf("\t.rodata : AT(ADDR(.rodata) - 0x%lx) "
	    "{ *(.rodata*) } > RAM\n", ramv-ramb);
	printf("\t.data : AT(ADDR(.data) - 0x%lx) "
	    "{ *(.data*) } > RAM\n", ramv-ramb);
	printf("\t. = ALIGN(4);\n\t__bss_start = .;\n");
	x = tabn ? "EXCLUDE_FILE(*/c.o) " : "";
	printf("\t.bss : AT(ADDR(.bss) - 0x%lx) {\n"
	    "\t\t*(%s.bss*)\n\t\t*(%sCOMMON)\n\t} > RAM\n",
	    ramv-ramb, x, x);
	printf("\t__bss_end = .;\n");
	printf("\t.ddrbss (NOLOAD) : ALIGN(4096) {\n");
	printf("\t\t__ddrbss_start = .;\n\t\t*(.ddrbss*)\n");
	if (tabn)
		printf("\t\t*/c.o(.bss* COMMON)\n");
	printf("\t\t__ddrbss_end = .;\n\t} > %s\n}\n",
	    tabn ? "TAB" : "RAM");

/*
 * pass 2 -- create configuration table
 */

	freopen("c.c", "w", stdout);
	/*
	 * declarations
	 */
	puke(stre);
	for (i=0; (q=btab[i]); i++) {
		for (p=table; p->name; p++)
		if (equal(q, p->name) &&
		   (p->key&BLOCK) && p->count && *p->codef)
			printf("%s\n", p->codef);
	}
	puke(stre1);
	for(i=0; (q=btab[i]); i++) {
		for(p=table; p->name; p++)
		if(equal(q, p->name) &&
		   (p->key&BLOCK) && p->count) {
			printf("\t/* %s %d */\n\t{%s},\n", q, i,
			    p->coded + (*p->coded == '\t'));
			if(p->key & ROOT)
				rootmaj = i;
			if (p->key & SWAP)
				swapmaj = i;
			if (p->key & PIPE)
				pipemaj = i;
			goto newb;
		}
		printf("\t{nodev, nodev, nostrat, 0}, /* %s %d */\n", q,
		    i);
	newb:;
	}
	if (swapmaj == -1) {
		swapmaj = rootmaj;
		swapmin = rootmin;
	}
	if (pipemaj == -1) {
		pipemaj = rootmaj;
		pipemin = rootmin;
	}
	puke(strf);
	for (i=0; (q=ctab[i]); i++) {
		for (p=table; p->name; p++)
		if (equal(q, p->name) &&
		   (p->key&CHAR) && p->count && *p->codeg)
			printf("%s\n", p->codeg);
	}
	puke(strf1);
	for(i=0; (q=ctab[i]); i++) {
		for(p=table; p->name; p++)
		if(equal(q, p->name) &&
		   (p->key&CHAR) && p->count) {
			printf("\t/* %s %d */\n\t{%s},\n", q, i,
			    p->codee + (*p->codee == '\t'));
			goto newc;
		}
		printf("\t{nodev, nodev, nordwr, nordwr, noioctl, "
		    "nulltty, 0},"
		    " /* %s %d */\n", q, i);
	newc:;
	}
	puke(strh);
	if (pack) {
		nldisp++;
		puke(stri);
	}
	puke(strj);
	if (pack)
		puke(strk);
	printf(strg, rootmaj, rootmin,
		swapmaj, swapmin,
		pipemaj, pipemin,
		nldisp,
		swplo, nswap);
	printf(strg1);
	printf(strg2);
	printf(strg3);
	if(rootmaj < 0)
		fprintf(stderr, "No root device given\n");
	printf("\nunsigned int\tcorebase, coreoff, coretop = 0x%lx;\n",
	    coret);
	printf("unsigned int\tgicdbase = 0x%lx, giccbase = 0x%lx;\n",
	    gicd, gicc);
	printf("\nstruct\tmemregion\tboard_map[] =\n{\n");
	for (i=0; i<nmap; i++)
		printf("\t{0x%lx, 0x%lx, 0x%lx, %s},\n", mapv[i],
		    mapb[i], mape[i], mapa[i]);
	printf("\t{0, 0, 0, 0}\n};\n");
	printf("\nextern int\tclkirq, klirq, rkirq;\n");
	printf("struct\tintr\tintrtab[] =\n{\n");
	printf("\t{&clkirq, clock},\n\t{&klirq, klintr},\n\t"
	    "{&rkirq, rkintr},\n");
	printf("\t{0, 0}\n};\n");
	printf("\nvoid\tcninit(void) { klinit(); }\n");
	printf("void\tbdinit(void) { rkinit(); }\n");
	printf("void\tclock_ddr_init(void) { %s}\n",
	    ddr ? "ddrinit(); " : "");
}

void
puke(char **s)
{
	char *c;

	while((c = *s++)) {
		printf(c);
		printf("\n");
	}
}

int
input(void)
{
	char line[100];
	register struct tab *q;
	int count, n;
	long num;
	char keyw[100], dev[100];

	if (fgets(line, 100, stdin) == NULL)
		return(0);
	count = -1;
	n = sscanf(line, "%d%s%s%ld", &count, keyw, dev, &num);
	if (count == -1) {
		count = 1;
		n = sscanf(line, "%s%s%ld", keyw, dev, &num) + 1;
	}
	if (n<2)
		goto badl;
	if (equal(keyw, "map") && nmap < NMAP) {
		if (sscanf(line, "%*s%lx%lx%lx%s", &mapv[nmap],
		    &mapb[nmap], &mape[nmap], mapa[nmap]) != 4)
			goto badl;
		nmap++;
		return(1);
	}
	if (equal(keyw, "ram"))
		return(sscanf(line, "%*s%lx%lx%lx", &ramv, &ramb,
		    &ramn) == 3 || badline(line));
	if (equal(keyw, "tables"))
		return(sscanf(line, "%*s%lx%lx%lx", &tabv, &tabb,
		    &tabn) == 3 || badline(line));
	if (equal(keyw, "core"))
		return(sscanf(line, "%*s%lx", &coret) == 1 ||
		    badline(line));
	if (equal(keyw, "gic"))
		return(sscanf(line, "%*s%lx%lx", &gicd, &gicc) == 2 ||
		    badline(line));
	if (equal(keyw, "ddr")) {
		ddr++;
		return(1);
	}
	for(q=table; q->name; q++)
	if(equal(q->name, keyw)) {
		if(q->count < 0) {
			fprintf(stderr, "%s: no more, no less\n", keyw);
			return(1);
		}
		q->count += count;
		if(q->address < 300 && q->count > 1) {
			q->count = 1;
			fprintf(stderr, "%s: only one\n", keyw);
		}
		return(1);
	}
	if (equal(keyw, "nswap")) {
		if (n<3)
			goto badl;
		if (sscanf(dev, "%ld", &num) <= 0)
			goto badl;
		nswap = num;
		return(1);
	}
	if (equal(keyw, "swplo")) {
		if (n<3)
			goto badl;
		if (sscanf(dev, "%ld", &num) <= 0)
			goto badl;
		swplo = num;
		return(1);
	}
	if (equal(keyw, "pack")) {
		pack++;
		return(1);
	}
	if (equal(keyw, "mpx")) {
		mpx++;
		return(1);
	}
	if(equal(keyw, "done"))
		return(0);
	if (equal(keyw, "root")) {
		if (n<4)
			goto badl;
		for (q=table; q->name; q++) {
			if (equal(q->name, dev)) {
				q->key |= ROOT;
				rootmin = num;
				return(1);
			}
		}
		fprintf(stderr, "Can't find root\n");
		return(1);
	}
	if (equal(keyw, "swap")) {
		if (n<4)
			goto badl;
		for (q=table; q->name; q++) {
			if (equal(q->name, dev)) {
				q->key |= SWAP;
				swapmin = num;
				return(1);
			}
		}
		fprintf(stderr, "Can't find swap\n");
		return(1);
	}
	if (equal(keyw, "pipe")) {
		if (n<4)
			goto badl;
		for (q=table; q->name; q++) {
			if (equal(q->name, dev)) {
				q->key |= PIPE;
				pipemin = num;
				return(1);
			}
		}
		fprintf(stderr, "Can't find pipe\n");
		return(1);
	}
	fprintf(stderr, "%s: cannot find\n", keyw);
	return(1);
badl:
	return(badline(line));
}

int
badline(char *line)
{
	fprintf(stderr, "Bad line: %s", line);
	return(1);
}

int
equal(char *a, char *b)
{
	return(!strcmp(a, b));
}
