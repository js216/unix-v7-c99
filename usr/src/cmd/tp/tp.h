/*	c-version of tp?.s
 *
 *	M. Ferentz
 *	August 1976
 *
 *	revised July 1977 BTL
 */

#define	MDIRENT	496		/* must be zero mod 8 */
#define DIRSZ	sizeof(struct dent)
#define MAPSIZE 4096
#define MAPMASK 07777
#define NAMELEN 32
#define BSIZE   512
#define	TCSIZ	578
#define TCDIRS	192
#define	MTSIZ	32767
#define TPB	(BSIZE/sizeof(struct tent))
#define	OK	0100000
#define	BRKINCR	512

#define	tapeblk	&tpentry[0]
#define tapeb	&tpentry[0]

extern struct 	tent	{	/* Structure of a tape directory block */
	char	pathnam[NAMELEN];
	short	mode;
	char	uid;
	char	gid;
	char	spare;
	char	size0;
	unsigned short	size1;
	long long	time;
	unsigned short	tapea;	/* tape address */
	short	unused[6];
	short	cksum;
}	tpentry[TPB];

extern struct	dent {	/* in core version of tent with "unused" removed
		 * and pathname replaced by pointer to same in a
		 * packed area (nameblock).
		 */
	char	*d_namep;
	int	d_mode;
	int	d_uid;
	int	d_gid;
	long	d_size;
	long long	d_time;
	int	d_tapea;
}  dir[MDIRENT];

extern char	map[MAPSIZE];
extern char	name[2*NAMELEN];
extern char	name1[NAMELEN];
extern	char mt[];
extern	char tc[];
extern char	*tname;
extern	char mheader[];
extern	char theader[];

extern int	narg, rnarg;
extern char	**parg;
extern int	wseeka,rseeka;
extern int	tapsiz;
extern int	fio;
extern short	ndirent, ndentb;
extern struct	dent	*edir;
extern struct	dent *lastd;		/* for improvement */
extern void	(*command)(void);
void	optap(void), setcom(void (*newcom)(void)), useerr(void), check(void), done(void), encode(char *pname, struct dent *dptr), decode(char *pname, struct dent *dptr), clrdir(void), clrent(struct dent *ptr), rddir(void), wrdir(void), tread(void), twrite(void), rseek(int blk), wseek(int blk), seekerr(void), getfiles(void), expand(void), fserr(void), callout(void), swabdir(struct tent *tp), gettape(void (*how)(struct dent *d)), delete(struct dent *dd), update(void), update1(void), phserr(void), bitmap(void), setmap(struct dent *d), maperr(void), usage(void), taboc(struct dent *dd), extract(struct dent *d), cmd(void), cmr(void), cmx(void), cmt(void);
int	verify(int key);

extern char	*nameblk;
extern char	*top;
extern char	*nptr;

extern	int	flags;
#define	flc	0001
#define	fli	0004
#define	flm	0010
#define	flu	0020
#define	flv	0040
#define	flw	0100
#define fls	0200
