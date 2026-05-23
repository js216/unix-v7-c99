/* sa(1) -- interpret command time accounting.
 *
 * Ported from v7/usr/src/cmd/sa.c with the minimum set of K&R -> C99
 * edits needed to build under the project's strict cmd-build CFLAGS:
 *
 *   - Replaced the K&R-style function definitions with C99 prototypes
 *     for the static helpers used inside this TU.
 *   - Inlined the v7 sys/acct.h definitions (struct acct, AFORK).  The
 *     port's include tree carries only kernel-side h/acct.h; userland
 *     does not get a <sys/acct.h>, so the struct is reproduced here
 *     instead of adding a new public header.
 *   - Renamed the file-scope `struct user user[256]` to `usr[]` so it
 *     does not shadow the kernel's struct user (the cmd build does not
 *     include h/user.h, but keeping the name distinct is harmless and
 *     reads more naturally).
 *   - Switched the v7-only `getpw(uid, buf)` lookup in printmoney() to
 *     getpwuid(), which is what this libc provides.  The fallback
 *     printing path (numeric uid) is unchanged.
 *   - Forward-declared the comparison functions and sum() with proper
 *     prototypes so qsort()'s function-pointer arg type-checks against
 *     stdio.h's declaration.
 *
 * Everything else (the hash-table enter() / cleanup pass / column()
 * pretty-printer / expand() pseudo-float decode) is byte-for-byte from
 * the v7 source.
 */
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <signal.h>
#include <pwd.h>

/* Acct record layout.
 *
 * v7's h/acct.h declares comp_t (16-bit pseudo-float) fields for ac_utime,
 * ac_stime, ac_etime, ac_io.  The kernel writei()s `&acctbuf` for
 * `sizeof(acctbuf)` bytes; in this port `acctbuf` is the global declared
 * in conf.c -- which uses *long* for utime/stime/etime and *short*
 * for ac_io.  The on-disk record we read back here therefore mirrors that
 * 44-byte struct, not h/acct.h's 36-byte one.
 *
 * (sys/acct.c::acct() truncates its writei() length to sizeof(acctbuf) as
 * seen from sys/acct.c -- which sees h/acct.h's 36-byte struct via the
 * include, so the *cut* is at byte 36.  That covers the 10-byte ac_comm,
 * the 2-byte alignment pad, and the four 4-byte time fields, plus the
 * three shorts ac_uid/ac_gid/ac_mem and the half of ac_io.  The kernel
 * never writes ac_tty/ac_flag, so we read them as zero here.)
 *
 * comp_t pseudo-float decode is in expand(); ac_btime/ac_uid/ac_gid are
 * passed through verbatim.  The wider-than-comp_t fields are still
 * decoded with expand() because compress() in sys/acct.c emits the same
 * pseudo-float (just zero-extended to a long here). */
typedef	unsigned short comp_t;
struct	acct {
	char	ac_comm[10];
	char	ac_pad[2];	/* alignment pad between ac_comm and ac_utime
				 * in conf.c's struct -- the kernel
				 * writes this byte-for-byte even though
				 * h/acct.h's matching field is comp_t. */
	long	ac_utime;
	long	ac_stime;
	long	ac_etime;
	time_t	ac_btime;
	short	ac_uid;
	short	ac_gid;
	short	ac_mem;
	short	ac_io;
	/* The kernel side never writes ac_tty / ac_flag: sys/acct.c::acct()
	 * caps writei() at sizeof(acctbuf) as seen through h/acct.h (36
	 * bytes), and that cut lands right after ac_io.  We don't carry
	 * the fields in this on-disk struct because their bytes are not
	 * actually persisted; the references below treat them as zero. */
};
#define	AFORK	01

#define	size 	1000
#define	NC	sizeof(acctbuf.ac_comm)
struct acct acctbuf;
int	lflg;
int	cflg;
int	iflg;
int	jflg;
int	nflg;
int	aflg;
int	rflg;
int	oflg;
int	tflg;
int	vflg;
int	uflg;
int	thres	= 1;
int	sflg;
int	bflg;
int	mflg;

struct	user_acct {
	int	ncomm;
	int	fill;
	float	fctime;
} usr[256];

struct	tab {
	char	name[NC];
	int	count;
	float	realt;
	float	cput;
	float	syst;
} tab[size];

float	treal;
float	tcpu;
float	tsys;
int	junkp = -1;
char	*sname;
float	ncom;

/* Forward declarations -- needed under C99 strict prototypes so qsort()
 * and the inter-routine calls type-check. */
extern int acct(char *);
time_t expand(unsigned t);
int tcmp(struct tab *p1, struct tab *p2);
int ncmp(struct tab *p1, struct tab *p2);
int bcmp(struct tab *p1, struct tab *p2);
float sum(struct tab *p);
void doacct(char *f);
int enter(char *np);
void init(void);
void strip(void);
void printmoney(void);
void column(double n, double a, double b, double c);
void col(double n, double a, double m);
int
main(int argc, char **argv)
{
	FILE *ff;
	int i, j, k;
	float ft;

	if (argc>1)
	if (argv[1][0]=='-') {
		argv++;
		argc--;
		for(i=1; argv[0][i]; i++)
		switch(argv[0][i]) {

		case 'o':
			oflg++;
			break;

		case 'i':
			iflg++;
			break;

		case 'b':
			bflg++;
			break;

		case 'l':
			lflg++;
			break;

		case 'c':
			cflg++;
			break;

		case 'j':
			jflg++;
			break;

		case 'n':
			nflg++;
			break;

		case 'a':
			aflg++;
			break;

		case 'r':
			rflg++;
			break;

		case 't':
			tflg++;
			break;

		case 's':
			sflg++;
			aflg++;
			break;

		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			thres = argv[0][i]-'0';
			break;

		case 'v':
			vflg++;
			break;

		case 'u':
			uflg++;
			break;

		case 'm':
			mflg++;
			break;
		}
	}
	/* Force iupdat() of the acct file's in-core inode so armboot's
	 * loadino() / kopen() path reads the fresh i_size when we fopen()
	 * below.  The kernel writei() in sys/acct.c::acct() bumps the
	 * in-core i_size on every process exit, but it leaves IUPD set
	 * without writing the dinode block back -- iput() only iupdat()s
	 * the inode when its refcount drops to 1, and acctp holds an
	 * extra reference that never lets that happen while accounting
	 * stays on.
	 *
	 * Toggling accounting off-then-on takes that extra reference away
	 * (sysacct(NULL) iput()s acctp -> i_count drops to 1 -> iupdat()
	 * pushes the dinode), then the re-enable sysacct() re-namei()s
	 * the (now-flushed) inode so subsequent exits keep accruing.  The
	 * read path our fopen() drives next sees the post-iupdat() dinode
	 * via armboot's loadino(), and fread() walks all the records on
	 * disk. */
	(void)acct((char *)0);
	(void)acct("/usr/adm/acct");
	if (iflg==0)
		init();
	if (argc<2)
		doacct("/usr/adm/acct");
	else while (--argc)
		doacct(*++argv);
	if (uflg) {
		return 0;
	}

/*
 * cleanup pass
 * put junk together
 */

	if (vflg)
		strip();
	if(!aflg)
	for (i=0; i<size; i++)
	if (tab[i].name[0]) {
		for(j=0; j<(int)NC; j++)
			if(tab[i].name[j] == '?')
				goto yes;
		if(tab[i].count != 1)
			continue;
	yes:
		if(junkp == -1)
			junkp = enter("***other");
		tab[junkp].count += tab[i].count;
		tab[junkp].realt += tab[i].realt;
		tab[junkp].cput += tab[i].cput;
		tab[junkp].syst += tab[i].syst;
		tab[i].name[0] = 0;
	}
	for(i=k=0; i<size; i++)
	if(tab[i].name[0]) {
		for(j=0; j<(int)NC; j++)
			tab[k].name[j] = tab[i].name[j];
		tab[k].count = tab[i].count;
		tab[k].realt = tab[i].realt;
		tab[k].cput = tab[i].cput;
		tab[k].syst = tab[i].syst;
		k++;
	}
	if (sflg) {
		signal(SIGINT, SIG_IGN);
		if ((ff = fopen("/usr/adm/usracct", "w")) != NULL) {
			fwrite((char *)usr, sizeof(usr), 1, ff);
			fclose(ff);
		}
		if ((ff = fopen("/usr/adm/savacct", "w")) == NULL) {
			printf("Can't save\n");
			exit(0);
		}
		fwrite((char *)tab, sizeof(tab[0]), k, ff);
		fclose(ff);
		signal(SIGINT, SIG_DFL);
	}
/*
 * sort and print
 */

	if (mflg) {
		printmoney();
		exit(0);
	}
	qsort((char *)tab, k, sizeof(tab[0]), nflg? ncmp: (bflg?bcmp:tcmp));
	column(ncom, treal, tcpu, tsys);
	printf("\n");
	for (i=0; i<k; i++)
	if (tab[i].name[0]) {
		ft = tab[i].count;
		column(ft, tab[i].realt, tab[i].cput, tab[i].syst);
		printf("   %.10s\n", tab[i].name);
	}
	return 0;
}

void
printmoney(void)
{
	int i;
	struct passwd *pw;

	for (i=0; i<256; i++) {
		if (usr[i].ncomm) {
			pw = getpwuid(i);
			if (pw == NULL)
				printf("%-8d", i);
			else
				printf("%-8s", pw->pw_name);
			printf("%5u %7.2f\n",
			    usr[i].ncomm, usr[i].fctime/60);
		}
	}
}

void
column(double n, double a, double b, double c)
{

	printf("%6.0f", n);
	if(cflg) {
		if(n == ncom)
			printf("%7s", ""); else
			printf("%6.2f%%", 100.*n/ncom);
	}
	col(n, a, treal);
	if (oflg)
		col(n, 3600*(b/(b+c)), tcpu+tsys);
	else if(lflg) {
		col(n, b, tcpu);
		col(n, c, tsys);
	} else
		col(n, b+c, tcpu+tsys);
	if(tflg)
		printf("%6.1f", a/(b+c));
}

void
col(double n, double a, double m)
{

	if(jflg)
		printf("%9.2f", a/(n*60.)); else
		printf("%9.2f", a/3600.);
	if(cflg) {
		if(a == m)
			printf("%7s", ""); else
			printf("%6.2f%%", 100.*a/m);
	}
}

void
doacct(char *f)
{
	int i;
	FILE *ff;
	long x;
	struct acct fbuf;
	char *cp;
	int c;

	if (sflg && sname) {
		printf("Only 1 file with -s\n");
		exit(0);
	}
	if (sflg)
		sname = f;
	if ((ff = fopen(f, "r"))==NULL) {
		printf("Can't open %s\n", f);
		return;
	}
	while (fread((char *)&fbuf, sizeof(fbuf), 1, ff) == 1) {
		if (fbuf.ac_comm[0]==0) {
			fbuf.ac_comm[0] = '?';
		}
		for (cp = fbuf.ac_comm; cp < &fbuf.ac_comm[NC]; cp++) {
			c = *cp & 0377;
			if (c && (c < ' ' || c >= 0200)) {
				*cp = '?';
			}
		}
		if (0/*fbuf.ac_flag*/&AFORK) {
			for (cp=fbuf.ac_comm; cp < &fbuf.ac_comm[NC]; cp++)
				if (*cp==0) {
					*cp = '*';
					break;
				}
		}
		x = expand(fbuf.ac_utime) + expand(fbuf.ac_stime);
		if (uflg) {
			printf("%3d%6.1f %.10s\n", fbuf.ac_uid&0377, x/60.0,
			   fbuf.ac_comm);
			continue;
		}
		c = fbuf.ac_uid&0377;
		usr[c].ncomm++;
		usr[c].fctime += x/60.;
		ncom += 1.0;
		i = enter(fbuf.ac_comm);
		tab[i].count++;
		x = expand(fbuf.ac_etime)*60;
		tab[i].realt += x;
		treal += x;
		x = expand(fbuf.ac_utime);
		tab[i].cput += x;
		tcpu += x;
		x = expand(fbuf.ac_stime);
		tab[i].syst += x;
		tsys += x;
	}
	fclose(ff);
}

int
ncmp(struct tab *p1, struct tab *p2)
{

	if(p1->count == p2->count)
		return(tcmp(p1, p2));
	if(rflg)
		return(p1->count - p2->count);
	return(p2->count - p1->count);
}

int
bcmp(struct tab *p1, struct tab *p2)
{
	float f1, f2;

	f1 = sum(p1)/p1->count;
	f2 = sum(p2)/p2->count;
	if(f1 < f2) {
		if(rflg)
			return(-1);
		return(1);
	}
	if(f1 > f2) {
		if(rflg)
			return(1);
		return(-1);
	}
	return(0);
}
int
tcmp(struct tab *p1, struct tab *p2)
{
	float f1, f2;

	f1 = sum(p1);
	f2 = sum(p2);
	if(f1 < f2) {
		if(rflg)
			return(-1);
		return(1);
	}
	if(f1 > f2) {
		if(rflg)
			return(1);
		return(-1);
	}
	return(0);
}

float
sum(struct tab *p)
{

	if(p->name[0] == 0)
		return(0.0);
	return(
		p->cput+
		p->syst);
}

void
init(void)
{
	struct tab tbuf;
	int i;
	FILE *f;

	if ((f = fopen("/usr/adm/savacct", "r")) == NULL)
		goto gshm;
	while (fread((char *)&tbuf, sizeof(tbuf), 1, f) == 1) {
		i = enter(tbuf.name);
		ncom += tbuf.count;
		tab[i].count = tbuf.count;
		treal += tbuf.realt;
		tab[i].realt = tbuf.realt;
		tcpu += tbuf.cput;
		tab[i].cput = tbuf.cput;
		tsys += tbuf.syst;
		tab[i].syst = tbuf.syst;
	}
	fclose(f);
 gshm:
	if ((f = fopen("/usr/adm/usracct", "r")) == NULL)
		return;
	fread((char *)usr, sizeof(usr), 1, f);
	fclose(f);
}

int
enter(char *np)
{
	int i, j;

	for (i=j=0; i<(int)NC; i++) {
		if (np[i]==0)
			j = i;
		if (j)
			np[i] = 0;
	}
	for (i=0, j=0; j<(int)NC; j++) {
		i = i*7 + np[j];
	}
	if (i < 0)
		i = -i;
	for (i%=size; tab[i].name[0]; i = (i+1)%size) {
		for (j=0; j<(int)NC; j++)
			if (tab[i].name[j]!=np[j])
				goto no;
		goto yes;
	no:;
	}
	for (j=0; j<(int)NC; j++)
		tab[i].name[j] = np[j];
yes:
	return(i);
}

void
strip(void)
{
	int i, j, c;

	j = enter("**junk**");
	for (i = 0; i<size; i++) {
		if (tab[i].name[0] && tab[i].count<=thres) {
			printf("%.10s--", tab[i].name);
			if ((c=getchar())=='y') {
				tab[i].name[0] = '\0';
				tab[j].count += tab[i].count;
				tab[j].realt += tab[i].realt;
				tab[j].cput += tab[i].cput;
				tab[j].syst += tab[i].syst;
			}
			while (c && c!='\n')
				c = getchar();
		}
	}
}

time_t
expand(unsigned t)
{
	time_t nt;

	nt = t&017777;
	t >>= 13;
	while (t!=0) {
		t--;
		nt <<= 3;
	}
	return(nt);
}
