#
/*
 * sed -- stream  editor
 *
 *
 */

#define CBRA	1
#define	CCHR	2
#define	CDOT	4
#define	CCL	6
#define	CNL	8
#define	CDOL	10
#define	CEOF	11
#define CKET	12
#define CNULL	13
#define CLNUM	14
#define CEND	16
#define CDONT	17
#define	CBACK	18

#define	STAR	01

#define NLINES	256
#define	DEPTH	20
#define PTRSIZE	100
#define RESIZE	5000
#define	ABUFSIZE	20
#define	LBSIZE	4000
#define	ESIZE	256
#define	LABSIZE	50
#define NBRA	9

extern FILE	*fin;
extern struct reptr	*abuf[ABUFSIZE];
extern struct reptr **aptr;
extern char	*lastre;
extern char	ibuf[512];
extern char	*cbp;
extern char	*ebp;
extern char	genbuf[LBSIZE];
extern char	*loc1;
extern char	*loc2;
extern char	*locs;
extern char	seof;
extern char	*reend;
extern char	*lbend;
extern char	*hend;
extern char	*lcomend;
extern struct reptr	*ptrend;
extern int	eflag;
extern int	dolflag;
extern int	sflag;
extern int	jflag;
extern int	numbra;
extern int	delflag;
extern long	lnum;
extern char	linebuf[LBSIZE+1];
extern char	holdsp[LBSIZE+1];
extern char	*spend;
extern char	*hspend;
extern int	nflag;
extern int	gflag;
extern char	*braelist[NBRA];
extern char	*braslist[NBRA];
extern long	tlno[NLINES];
extern int	nlno;
extern char	fname[12][40];
extern FILE	*fcode[12];
extern int	nfiles;

#define ACOM	01
#define BCOM	020
#define CCOM	02
#define	CDCOM	025
#define	CNCOM	022
#define COCOM	017
#define	CPCOM	023
#define DCOM	03
#define ECOM	015
#define EQCOM	013
#define FCOM	016
#define GCOM	027
#define CGCOM	030
#define HCOM	031
#define CHCOM	032
#define ICOM	04
#define LCOM	05
#define NCOM	012
#define PCOM	010
#define QCOM	011
#define RCOM	06
#define SCOM	07
#define TCOM	021
#define WCOM	014
#define	CWCOM	024
#define	YCOM	026
#define XCOM	033

extern char	*cp;
extern char	*reend;
extern char	*lbend;

extern struct	reptr {
		char	*ad1;
		char	*ad2;
		char	*re1;
		struct reptr	*lb1;
		char	*rhs;
		FILE	*fcode;
		char	command;
		char	gfl;
		char	pfl;
		char	inar;
		char	negfl;
} ptrspace[PTRSIZE], *rep;


extern char	respace[RESIZE];

extern struct label {
	char	asc[9];
	struct reptr	*chain;
	struct reptr	*address;
} ltab[LABSIZE];

extern struct label	*lab;
extern struct label	*labend;

extern int	f;
extern int	depth;

extern int	eargc;
extern char	**eargv;

extern	unsigned char	bittab[];

extern struct reptr	**cmpend[DEPTH];
extern int	depth;
extern struct reptr	*pending;
extern char	*badp;
extern char	bad;
char	*compile(char *expbuf);
char	*ycomp(char *expbuf);
char	*address(char *expbuf);
char	*text(char *textbuf);
char	*compsub(char *rhsbuf);
struct label	*search(struct label *ptr);
char	*gline(char *addr);
char	*place(char *asp, char *al1, char *al2);
void	execute(char *file);
extern char	compfl;
