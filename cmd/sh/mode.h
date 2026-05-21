#
/*
 *	UNIX shell
 */


#define BYTESPERWORD	(sizeof(char *))

TYPE char	CHAR;
TYPE char	BOOL;
TYPE int	UFD;
TYPE int	INT;
TYPE float	REAL;
TYPE char	*ADDRESS;
TYPE long int	L_INT;
TYPE int	VOID;
TYPE unsigned	POS;
TYPE char	*STRING;
TYPE char	MSG[];
TYPE int	PIPE[];
TYPE char	*STKPTR;
TYPE char	*BYTPTR;

STRUCT stat	STATBUF;	/* defined in /usr/sys/stat.h */
STRUCT blk	*BLKPTR;
STRUCT fileblk	FILEBLK;
STRUCT filehdr	FILEHDR;
STRUCT fileblk	*FILE;
STRUCT trenod	*TREPTR;
STRUCT trenod	*FORKPTR;
STRUCT trenod	*COMPTR;
STRUCT trenod	*SWPTR;
STRUCT trenod	*REGPTR;
STRUCT trenod	*PARPTR;
STRUCT trenod	*IFPTR;
STRUCT trenod	*WHPTR;
STRUCT trenod	*FORPTR;
STRUCT trenod	*LSTPTR;
STRUCT argnod	*ARGPTR;
STRUCT dolnod	*DOLPTR;
STRUCT ionod	*IOPTR;
STRUCT namnod	NAMNOD;
STRUCT namnod	*NAMPTR;
STRUCT sysnod	SYSNOD;
STRUCT sysnod	*SYSPTR;
#define NIL	((char*)0)


/* the following nonsense is required
 * because casts turn an Lvalue
 * into an Rvalue so two cheats
 * are necessary, one for each context.
 */
#define Lcheat(a)	(*(int *)&(a))
#define Rcheat(a)	((int)(a))


/* address puns for storage allocation */
UNION {
	FORKPTR	_forkptr;
	COMPTR	_comptr;
	PARPTR	_parptr;
	IFPTR	_ifptr;
	WHPTR	_whptr;
	FORPTR	_forptr;
	LSTPTR	_lstptr;
	BLKPTR	_blkptr;
	NAMPTR	_namptr;
	BYTPTR	_bytptr;
	}	address;


/* heap storage */
struct blk {
	BLKPTR	word;
};

#define	BUFSIZ	64
struct fileblk {
	UFD	fdes;
	POS	flin;
	BOOL	feof;
	CHAR	fsiz;
	STRING	fnxt;
	STRING	fend;
	STRING	*feval;
	FILE	fstak;
	CHAR	fbuf[BUFSIZ];
};

/* for files not used with file descriptors */
struct filehdr {
	UFD	fdes;
	POS	flin;
	BOOL	feof;
	CHAR	fsiz;
	STRING	fnxt;
	STRING	fend;
	STRING	*feval;
	FILE	fstak;
	CHAR	_fbuf[1];
};

struct sysnod {
	STRING	sysnam;
	INT	sysval;
};
STRUCT sysnod	SYSTAB[];

/* this node is a proforma for those that follow.  C99 strict: the v7
 * K&R idiom of `t->forktyp' on a TREPTR (where forknod, comnod, etc.
 * were separate structs with parallel layouts) is replaced with a
 * single named-union trenod plus #define field aliases below; the
 * separate forknod/comnod/etc. types are gone (only their `sizeof'
 * was ever read, now expressed against the union members). */
struct trenod_tre  { INT tretyp;  IOPTR treio; };
struct trenod_fork { INT forktyp; IOPTR forkio;  TREPTR forktre; };
struct trenod_com  { INT comtyp;  IOPTR comio;   ARGPTR comarg; ARGPTR comset; };
struct trenod_if   { INT iftyp;   TREPTR iftre;  TREPTR thtre;  TREPTR eltre; };
struct trenod_wh   { INT whtyp;   TREPTR whtre;  TREPTR dotre; };
struct trenod_for  { INT fortyp;  TREPTR fortre; STRING fornam; COMPTR forlst; };
struct trenod_sw   { INT swtyp;   STRING swarg;  REGPTR swlst; };
struct trenod_par  { INT partyp;  TREPTR partre; };
struct trenod_lst  { INT lsttyp;  TREPTR lstlef; TREPTR lstrit; };
struct trenod_reg  { ARGPTR regptr; TREPTR regcom; REGPTR regnxt; };

struct trenod {
	union {
		struct trenod_tre  _tre;
		struct trenod_fork _fork;
		struct trenod_com  _com;
		struct trenod_if   _if;
		struct trenod_wh   _wh;
		struct trenod_for  _for;
		struct trenod_sw   _sw;
		struct trenod_par  _par;
		struct trenod_lst  _lst;
		struct trenod_reg  _reg;
	} u;
};

/* dummy for access only */
struct argnod {
	ARGPTR	argnxt;
	CHAR	argval[1];
};

struct dolnod {
	DOLPTR	dolnxt;
	INT	doluse;
	CHAR	dolarg[1];
};

struct ionod {
	INT	iofile;
	STRING	ioname;
	IOPTR	ionxt;
	IOPTR	iolst;
};

#define	FORKTYPE	(sizeof(struct trenod_fork))
#define	COMTYPE		(sizeof(struct trenod_com))
#define	IFTYPE		(sizeof(struct trenod_if))
#define	WHTYPE		(sizeof(struct trenod_wh))
#define	FORTYPE		(sizeof(struct trenod_for))
#define	SWTYPE		(sizeof(struct trenod_sw))
#define	REGTYPE		(sizeof(struct trenod_reg))
#define	PARTYPE		(sizeof(struct trenod_par))
#define	LSTTYPE		(sizeof(struct trenod_lst))
#define	IOTYPE		(sizeof(struct ionod))

/* Field-access macros: subsequent code writes `t->forktyp' etc., which
 * the preprocessor rewrites to `t->u._fork.forktyp' (literal field of
 * the named-union member).  Macros come AFTER all struct definitions
 * so the field declarations above stay un-rewritten. */
#define tretyp  u._tre.tretyp
#define treio   u._tre.treio
#define forktyp u._fork.forktyp
#define forkio  u._fork.forkio
#define forktre u._fork.forktre
#define comtyp  u._com.comtyp
#define comio   u._com.comio
#define comarg  u._com.comarg
#define comset  u._com.comset
#define iftyp   u._if.iftyp
#define iftre   u._if.iftre
#define thtre   u._if.thtre
#define eltre   u._if.eltre
#define whtyp   u._wh.whtyp
#define whtre   u._wh.whtre
#define dotre   u._wh.dotre
#define fortyp  u._for.fortyp
#define fortre  u._for.fortre
#define fornam  u._for.fornam
#define forlst  u._for.forlst
#define swtyp   u._sw.swtyp
#define swarg   u._sw.swarg
#define swlst   u._sw.swlst
#define partyp  u._par.partyp
#define partre  u._par.partre
#define lsttyp  u._lst.lsttyp
#define lstlef  u._lst.lstlef
#define lstrit  u._lst.lstrit
#define regptr  u._reg.regptr
#define regcom  u._reg.regcom
#define regnxt  u._reg.regnxt
