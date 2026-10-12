#define	_U	01
#define	_L	02
#define	_N	04
#define	_S	010
#define _P	020
#define _C	040
#define	_X	0100

extern	char	_ctype_[];	/* in /usr/src/libc/gen/ctype_.h */

#define	isalpha(c)	((_ctype_+1)[(c)&0377]&(_U|_L))
#define	isupper(c)	((_ctype_+1)[(c)&0377]&_U)
#define	islower(c)	((_ctype_+1)[(c)&0377]&_L)
#define	isdigit(c)	((_ctype_+1)[(c)&0377]&_N)
#define	isxdigit(c)	((_ctype_+1)[(c)&0377]&(_N|_X))
#define	isspace(c)	((_ctype_+1)[(c)&0377]&_S)
#define ispunct(c)	((_ctype_+1)[(c)&0377]&_P)
#define isalnum(c)	((_ctype_+1)[(c)&0377]&(_U|_L|_N))
#define isprint(c)	((_ctype_+1)[(c)&0377]&(_P|_U|_L|_N))
#define iscntrl(c)	((_ctype_+1)[(c)&0377]&_C)
#define isascii(c)	((unsigned)(c)<=0177)
#define toupper(c)	((c)-'a'+'A')
#define tolower(c)	((c)-'A'+'a')
#define toascii(c)	((c)&0177)
