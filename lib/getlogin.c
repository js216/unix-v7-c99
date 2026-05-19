#include <stdio.h>
#include <utmp.h>
extern int ttyslot(void);

static	char	UTMP[]	= "/etc/utmp";
static	struct	utmp ubuf;
static	char	name[9];

char *
getlogin()
{
	register int me, uf;
	register char *cp;

	if( !(me = ttyslot()) )
		return(0);
	if( (uf = open( UTMP, 0 )) < 0 )
		return(0);
	lseek( uf, (long)(me*(int)sizeof(ubuf)), 0 );
	if (read(uf, (char *)&ubuf, sizeof(ubuf)) != sizeof(ubuf))
		return(0);
	close(uf);
	strncpy(name, ubuf.ut_name, 8);
	name[8] = ' ';
	for (cp=name; *cp++!=' ';)
		;
	*--cp = '\0';
	return(name);
}
